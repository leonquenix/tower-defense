--!strict
-- Fronteira de rede: valida envelope, sessão, sequência, deduplicação e limites de taxa; despacha ações.
-- Nenhuma ação aceita dano, preço ou resultado vindos do cliente.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Protocol = require(Shared.Net.Protocol)
local MatchService = require(script.Parent.MatchService)
local PartyService = require(script.Parent.PartyService)
local MenuService = require(script.Parent.MenuService)
local TelemetryService = require(script.Parent.TelemetryService)

local CommandService = {}

type Session = {
	dedupe: Protocol.DedupeWindow,
	combat: Protocol.Bucket,
	persistent: Protocol.Bucket,
	snapshot: Protocol.Bucket,
	violations: number,
	lastSequence: number,
}

local sessions: { [number]: Session } = {}

local function newSession(): Session
	local now = os.clock()
	return {
		dedupe = Protocol.newDedupe(),
		combat = Protocol.newBucket(10, 20, now),
		persistent = Protocol.newBucket(1, 2, now),
		snapshot = Protocol.newBucket(0.5, 1, now),
		violations = 0,
		lastSequence = -1,
	}
end

local function respond(requestId: string, body: { [string]: any }): { [string]: any }
	body.requestId = requestId
	if body.ok == nil then
		body.ok = false
	end
	return body
end

local MATCH_ACTIONS: { [string]: boolean } = {
	PlaceTower = true,
	UpgradeTower = true,
	SellTower = true,
	SetTarget = true,
	CastPulse = true,
	SetReady = true,
	VoteSpeed = true,
	RequestSnapshot = true,
	LeaveMatch = true,
	TrainingSpawn = true,
	TrainingClear = true,
	TutorialAdvance = true,
	TutorialSkip = true,
	Rematch = true,
	DevCommand = true,
}
local PARTY_ACTIONS: { [string]: boolean } = {
	CreateParty = true,
	JoinParty = true,
	LeaveParty = true,
	InviteToParty = true,
	RespondInvite = true,
	KickFromParty = true,
	PartyReady = true,
	PartySetup = true,
	StartMatch = true,
}

local function dispatch(player: Player, envelope: Protocol.Envelope): { [string]: any }
	local action = envelope.action
	if action == "Telemetry" then
		TelemetryService.log(
			"client_" .. tostring(envelope.payload.event),
			{ userId = player.UserId, value = envelope.payload.value }
		)
		return { ok = true }
	end
	if MATCH_ACTIONS[action] then
		return MatchService.handle(player, action, envelope.payload)
	end
	if PARTY_ACTIONS[action] then
		return PartyService.handle(player, action, envelope.payload)
	end
	return MenuService.handle(player, action, envelope.payload)
end

local function onInvoke(player: Player, raw: any): { [string]: any }
	local session = sessions[player.UserId]
	if not session then
		session = newSession()
		sessions[player.UserId] = session
	end
	local envelope, err = Protocol.validateEnvelope(raw)
	if not envelope then
		session.violations += 1
		if session.violations % 20 == 0 then
			TelemetryService.log("protocol_violations", { userId = player.UserId, count = session.violations })
		end
		return respond(
			if typeof(raw) == "table" and typeof(raw.requestId) == "string" then raw.requestId:sub(1, 40) else "",
			{ ok = false, errorCode = err }
		)
	end
	local previous, staleErr = Protocol.checkDedupe(session.dedupe, envelope.requestId, envelope.sessionSequence)
	if previous ~= nil then
		return previous
	end
	if staleErr then
		return respond(envelope.requestId, { ok = false, errorCode = staleErr })
	end
	local now = os.clock()
	local bucket = session.combat
	if Protocol.PERSISTENT_ACTIONS[envelope.action] then
		bucket = session.persistent
	elseif Protocol.SNAPSHOT_ACTIONS[envelope.action] then
		bucket = session.snapshot
	end
	if not Protocol.takeToken(bucket, now) then
		return respond(envelope.requestId, { ok = false, errorCode = Protocol.ERROR.RATE_LIMIT })
	end
	local ok, body = pcall(dispatch, player, envelope)
	local response: { [string]: any }
	if ok then
		response = respond(envelope.requestId, body)
	else
		TelemetryService.log(
			"command_error",
			{ userId = player.UserId, action = envelope.action, error = tostring(body) }
		)
		response = respond(envelope.requestId, { ok = false, errorCode = Protocol.ERROR.INVALID_STATE })
	end
	Protocol.remember(session.dedupe, envelope.requestId, envelope.sessionSequence, response)
	return response
end

function CommandService.init(remote: RemoteFunction)
	remote.OnServerInvoke = onInvoke
	Players.PlayerRemoving:Connect(function(player: Player)
		-- nova sessão ao reconectar: a janela de deduplicação recomeça
		sessions[player.UserId] = nil
	end)
end

return CommandService
