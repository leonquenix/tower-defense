--!strict
-- Parties no mesmo servidor: líder, membros, prontidão, sala, convites internos e início de partida.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Balance = require(Shared.Config.Balance)
local Catalog = require(Shared.Config.Catalog)
local Protocol = require(Shared.Net.Protocol)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MatchService = require(script.Parent.MatchService)
local TelemetryService = require(script.Parent.TelemetryService)
local Server = require(script.Parent.Parent.Net.Server)

local PartyService = {}

export type Party = {
	id: string,
	leaderId: number,
	members: { number }, -- ordem de entrada (mais antigo primeiro)
	ready: { [number]: boolean },
	mapId: string,
	difficulty: Types.Difficulty,
	createdAt: number,
	inMatchId: string?,
}

-- Convite emitido pelo servidor. O inviteId é o token: só ele autoriza a entrada, e ele
-- vence em 30 s de relógio real. A UI mostra a contagem, mas quem decide é este registro.
export type Invite = {
	inviteId: string,
	partyId: string,
	fromUserId: number,
	toUserId: number,
	expiresAt: number,
}

local INVITE_TTL = 30
local INVITE_COOLDOWN = 5

local parties: { [string]: Party } = {}
local partyOf: { [number]: string } = {}
local invites: { [string]: Invite } = {}
-- Último convite enviado por (remetente -> destinatário), para o cooldown de 5 s.
local lastInviteAt: { [string]: number } = {}
local broadcastScheduled = false

local function pruneInvites(now: number)
	for inviteId, invite in pairs(invites) do
		if now >= invite.expiresAt then
			invites[inviteId] = nil
		end
	end
end

local function result(ok: boolean, code: string?, extra: { [string]: any }?): { [string]: any }
	local r: { [string]: any } = { ok = ok, errorCode = code }
	if extra then
		for k, v in pairs(extra) do
			r[k] = v
		end
	end
	return r
end

local function playerById(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function partyView(party: Party): { [string]: any }
	local members = {}
	for _, userId in ipairs(party.members) do
		local player = playerById(userId)
		local profile = if player then PlayerDataService.get(player) else nil
		table.insert(members, {
			userId = userId,
			name = if player then player.DisplayName else "?",
			ready = party.ready[userId] == true or userId == party.leaderId,
			loadout = if profile then table.clone(profile.loadout) else {},
			unlocked = if profile then ProfileSchema.isMapUnlocked(profile, party.mapId, party.difficulty) else false,
		})
	end
	return {
		id = party.id,
		leaderId = party.leaderId,
		members = members,
		mapId = party.mapId,
		difficulty = party.difficulty,
		inMatch = party.inMatchId ~= nil,
	}
end

function PartyService.lobbyView(player: Player): { [string]: any }
	local rooms = {}
	for _, party in pairs(parties) do
		if #party.members < Balance.partyMax and party.inMatchId == nil then
			local leader = playerById(party.leaderId)
			table.insert(rooms, {
				id = party.id,
				leaderName = if leader then leader.DisplayName else "?",
				size = #party.members,
				mapId = party.mapId,
				difficulty = party.difficulty,
			})
		end
	end
	table.sort(rooms, function(a, b)
		return a.id < b.id
	end)
	local present = {}
	for _, other in ipairs(Players:GetPlayers()) do
		table.insert(present, {
			userId = other.UserId,
			name = other.DisplayName,
			inMatch = MatchService.isInMatch(other.UserId),
			inParty = partyOf[other.UserId] ~= nil,
		})
	end
	local partyId = partyOf[player.UserId]
	local party = if partyId then parties[partyId] else nil
	return {
		profile = PlayerDataService.clientView(player),
		party = if party then partyView(party) else nil,
		rooms = rooms,
		players = present,
		inMatch = MatchService.isInMatch(player.UserId),
		build = TelemetryService.build(),
		maxPlayers = Balance.serverMaxPlayers,
	}
end

function PartyService.sendLobby(player: Player)
	Server.sendLobby(player, "lobby", PartyService.lobbyView(player))
end

function PartyService.broadcast()
	if broadcastScheduled then
		return
	end
	broadcastScheduled = true
	task.defer(function()
		broadcastScheduled = false
		for _, player in ipairs(Players:GetPlayers()) do
			if not MatchService.isInMatch(player.UserId) then
				PartyService.sendLobby(player)
			end
		end
	end)
end

local function removeFromParty(userId: number)
	local partyId = partyOf[userId]
	if not partyId then
		return
	end
	local party = parties[partyId]
	partyOf[userId] = nil
	if not party then
		return
	end
	local idx = table.find(party.members, userId)
	if idx then
		table.remove(party.members, idx)
	end
	party.ready[userId] = nil
	if #party.members == 0 then
		parties[partyId] = nil
	elseif party.leaderId == userId then
		party.leaderId = party.members[1]
		-- troca de composição limpa prontidão
		party.ready = {}
	end
	PartyService.broadcast()
end

local function createParty(player: Player): Party
	local party: Party = {
		id = HttpService:GenerateGUID(false):sub(1, 8),
		leaderId = player.UserId,
		members = { player.UserId },
		ready = {},
		mapId = "jardim",
		difficulty = "normal",
		createdAt = os.clock(),
		inMatchId = nil,
	}
	parties[party.id] = party
	partyOf[player.UserId] = party.id
	return party
end

local function startMatchFor(
	players: { Player },
	mapId: string,
	difficulty: Types.Difficulty,
	mode: Types.MatchMode,
	partyId: string?
): { [string]: any }
	if mode ~= "normal" and #players ~= 1 then
		return result(false, Protocol.ERROR.INVALID_STATE)
	end
	for _, player in ipairs(players) do
		if MatchService.isInMatch(player.UserId) then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		local profile = PlayerDataService.get(player)
		if mode == "normal" then
			if not profile then
				return result(false, Protocol.ERROR.PROFILE_UNAVAILABLE)
			end
			if not ProfileSchema.isMapUnlocked(profile, mapId, difficulty) then
				return result(false, Protocol.ERROR.INVALID_STATE, { reason = "map_locked", userId = player.UserId })
			end
			if #profile.loadout == 0 then
				return result(false, Protocol.ERROR.INVALID_STATE, { reason = "empty_loadout", userId = player.UserId })
			end
		end
		if mode == "tutorial" and profile == nil and PlayerDataService.getStatus(player) ~= "unavailable" then
			return result(false, Protocol.ERROR.PROFILE_UNAVAILABLE)
		end
	end
	local match, err = MatchService.start({
		players = players,
		mapId = mapId,
		difficulty = difficulty,
		mode = mode,
		partyId = partyId,
	})
	if not match then
		return result(false, err)
	end
	if partyId then
		local party = parties[partyId]
		if party then
			party.inMatchId = match.id
			party.ready = {}
		end
	end
	PartyService.broadcast()
	return result(true, nil, { matchId = match.id })
end

function PartyService.handle(player: Player, action: string, payload: { [string]: any }): { [string]: any }
	local userId = player.UserId
	local partyId = partyOf[userId]
	local party = if partyId then parties[partyId] else nil

	if action == "CreateParty" then
		if party then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		local created = createParty(player)
		PartyService.broadcast()
		return result(true, nil, { partyId = created.id })
	elseif action == "JoinParty" then
		if party then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		local target = parties[payload.partyId]
		if not target or target.inMatchId or #target.members >= Balance.partyMax then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		table.insert(target.members, userId)
		partyOf[userId] = target.id
		target.ready = {} -- composição mudou
		PartyService.broadcast()
		return result(true, nil, { partyId = target.id })
	elseif action == "LeaveParty" then
		removeFromParty(userId)
		return result(true)
	elseif action == "InviteToParty" then
		local now = os.clock()
		pruneInvites(now)
		if payload.userId == userId then
			return result(false, Protocol.ERROR.BAD_REQUEST)
		end
		local target = playerById(payload.userId)
		if not target or partyOf[target.UserId] or MatchService.isInMatch(target.UserId) then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		-- cooldown por destinatário: nada de repetir automaticamente
		local cooldownKey = userId .. ">" .. target.UserId
		local last = lastInviteAt[cooldownKey]
		if last and now - last < INVITE_COOLDOWN then
			return result(false, Protocol.ERROR.RATE_LIMIT)
		end
		local inviteParty: Party = party or createParty(player)
		if inviteParty.inMatchId or #inviteParty.members >= Balance.partyMax then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		lastInviteAt[cooldownKey] = now
		local invite: Invite = {
			inviteId = HttpService:GenerateGUID(false):sub(1, 12),
			partyId = inviteParty.id,
			fromUserId = userId,
			toUserId = target.UserId,
			expiresAt = now + INVITE_TTL,
		}
		invites[invite.inviteId] = invite
		Server.sendLobby(target, "invite", {
			inviteId = invite.inviteId,
			partyId = inviteParty.id,
			fromName = player.DisplayName,
			fromUserId = userId,
			mapId = inviteParty.mapId,
			difficulty = inviteParty.difficulty,
			expiresIn = INVITE_TTL,
		})
		PartyService.broadcast()
		return result(true, nil, { inviteId = invite.inviteId })
	elseif action == "RespondInvite" then
		local now = os.clock()
		pruneInvites(now)
		local invite = invites[payload.inviteId]
		-- token inexistente, de outra pessoa ou vencido: nenhuma entrada acontece
		if not invite or invite.toUserId ~= userId then
			return result(false, Protocol.ERROR.INVALID_STATE, { reason = "invite_invalid" })
		end
		invites[invite.inviteId] = nil
		if payload.accept ~= true then
			return result(true, nil, { declined = true })
		end
		if party then
			return result(false, Protocol.ERROR.INVALID_STATE, { reason = "already_in_party" })
		end
		if MatchService.isInMatch(userId) then
			return result(false, Protocol.ERROR.INVALID_STATE, { reason = "in_match" })
		end
		local target = parties[invite.partyId]
		-- entrada atômica: dois aceites para a última vaga resultam em uma entrada
		if not target or target.inMatchId or #target.members >= Balance.partyMax then
			return result(false, Protocol.ERROR.INVALID_STATE, { reason = "party_full" })
		end
		table.insert(target.members, userId)
		partyOf[userId] = target.id
		target.ready = {} -- composição mudou: prontidão limpa
		PartyService.broadcast()
		return result(true, nil, { partyId = target.id })
	elseif action == "KickFromParty" then
		if not party or party.leaderId ~= userId or payload.userId == userId then
			return result(false, Protocol.ERROR.NOT_OWNER)
		end
		if table.find(party.members, payload.userId) then
			removeFromParty(payload.userId)
			local kicked = playerById(payload.userId)
			if kicked then
				PartyService.sendLobby(kicked)
			end
		end
		return result(true)
	elseif action == "PartyReady" then
		if not party then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		party.ready[userId] = payload.ready == true
		PartyService.broadcast()
		return result(true)
	elseif action == "PartySetup" then
		if not party or party.leaderId ~= userId then
			return result(false, Protocol.ERROR.NOT_OWNER)
		end
		if not Catalog.getMap(payload.mapId) or not Catalog.getDifficulty(payload.mode) then
			return result(false, Protocol.ERROR.BAD_REQUEST)
		end
		party.mapId = payload.mapId
		party.difficulty = payload.mode
		party.ready = {}
		PartyService.broadcast()
		return result(true)
	elseif action == "StartMatch" then
		local matchMode: Types.MatchMode = "normal"
		if payload.matchMode == "tutorial" or payload.matchMode == "training" then
			matchMode = payload.matchMode
		end
		local difficulty = payload.mode
		if difficulty ~= "normal" and difficulty ~= "desafio" then
			return result(false, Protocol.ERROR.BAD_REQUEST)
		end
		if not Catalog.getMap(payload.mapId) then
			return result(false, Protocol.ERROR.BAD_REQUEST)
		end
		if matchMode ~= "normal" then
			-- tutorial e treino são sempre solo e não exigem party
			return startMatchFor(
				{ player },
				if matchMode == "tutorial" then "jardim" else payload.mapId,
				"normal",
				matchMode,
				nil
			)
		end
		if not party or #party.members == 1 then
			if party then
				party.mapId = payload.mapId
				party.difficulty = difficulty
			end
			return startMatchFor({ player }, payload.mapId, difficulty, "normal", if party then party.id else nil)
		end
		if party.leaderId ~= userId then
			return result(false, Protocol.ERROR.NOT_OWNER)
		end
		local players: { Player } = {}
		for _, memberId in ipairs(party.members) do
			local member = playerById(memberId)
			if not member then
				return result(false, Protocol.ERROR.INVALID_STATE, { reason = "member_absent" })
			end
			if memberId ~= party.leaderId and not party.ready[memberId] then
				return result(false, Protocol.ERROR.INVALID_STATE, { reason = "not_ready", userId = memberId })
			end
			table.insert(players, member)
		end
		return startMatchFor(players, party.mapId, party.difficulty, "normal", party.id)
	end
	return result(false, Protocol.ERROR.BAD_REQUEST)
end

-- Revanche: nova partida com os presentes que confirmaram
function PartyService.onRematch(previous: MatchService.Match, players: { Player })
	local state = previous.state
	local partyId = previous.partyId
	local party = if partyId then parties[partyId] else nil
	if party then
		party.inMatchId = nil
	end
	local r = startMatchFor(players, state.mapId, state.difficulty, state.mode, partyId)
	if not r.ok then
		for _, player in ipairs(players) do
			PartyService.sendLobby(player)
		end
	end
end

function PartyService.onPlayerFreed(player: Player)
	local partyId = partyOf[player.UserId]
	local party = if partyId then parties[partyId] else nil
	if party and party.inMatchId and not MatchService.isInMatch(party.leaderId) then
		party.inMatchId = nil
	end
	PartyService.sendLobby(player)
	PartyService.broadcast()
end

function PartyService.onPlayerAdded(player: Player)
	PartyService.sendLobby(player)
	PartyService.broadcast()
end

function PartyService.onPlayerRemoving(player: Player)
	removeFromParty(player.UserId)
	-- convites de e para quem saiu deixam de existir
	for inviteId, invite in pairs(invites) do
		if invite.fromUserId == player.UserId or invite.toUserId == player.UserId then
			invites[inviteId] = nil
		end
	end
	PartyService.broadcast()
end

function PartyService.init()
	PlayerDataService.onSessionChanged(function(player: Player)
		if player.Parent == Players and not MatchService.isInMatch(player.UserId) then
			PartyService.sendLobby(player)
		end
	end)
end

return PartyService
