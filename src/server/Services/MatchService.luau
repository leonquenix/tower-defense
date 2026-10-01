--!strict
-- Instâncias lógicas de partida: passo fixo com acumulador, comandos, replicação a 10 Hz,
-- fases da campanha, presença, abandono, resultado e revanche.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Balance = require(Shared.Config.Balance)
local Catalog = require(Shared.Config.Catalog)
local Simulation = require(Shared.Sim.Simulation)
local Snapshot = require(Shared.Sim.Snapshot)
local Protocol = require(Shared.Net.Protocol)
local Products = require(Shared.Config.Products)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local Progression = require(Shared.Rules.Progression)
local Server = require(script.Parent.Parent.Net.Server)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local TelemetryService = require(script.Parent.TelemetryService)

local MatchService = {}

local STEP = Simulation.STEP
local MAX_STEPS_PER_HEARTBEAT = 6
local MAX_ACCUMULATOR = 0.5
local FRAME_INTERVAL = 1 / Balance.snapshotRate -- 10 Hz
local FULL_INTERVAL = 2
local ABSENT_INACTIVE_SECONDS = 30
local ABANDON_SECONDS = 60
local CLOSE_AFTER_RESULT_SECONDS = 120
local OVERLOAD_WINDOW = 10
local OVERLOAD_LIMIT = 20
local DEV_ALLOWLIST: { [number]: boolean } = {} -- UserIds autorizados fora do Studio (vazio por padrão)

export type Match = {
	id: string,
	state: Types.MatchState,
	players: { [number]: Player },
	explicitlyLeft: { [number]: boolean },
	accumulator: number,
	lastFrameAt: number,
	lastFullAt: number,
	pendingEvents: { Types.SimEvent },
	needFull: boolean,
	absentSince: { [number]: number },
	allAbsentSince: number?,
	settled: boolean,
	settling: boolean,
	resultAt: number?,
	rematchReady: { [number]: boolean },
	overloadCount: number,
	overloadWindowStart: number,
	createdAt: number,
	outcomes: { [number]: RewardService.UserOutcome }?,
	partyId: string?,
	-- Retomada: prazo real da decisão (os.clock) e quem já disse "não"
	retryDeadline: number?,
	retryDeclined: { [number]: boolean },
}

local matches: { [string]: Match } = {}
local playerMatch: { [number]: string } = {}
local onPlayerFreed: ((Player) -> ())? = nil
local onRematch: ((Match, { Player }) -> ())? = nil

-- Quadros vão por ByteNet (Server.sendFrame codifica o snapshot); avisos raros usam sendMatchInfo.
local function send(player: Player, kind: string, payload: any, extra: any?)
	if kind == "frame" then
		Server.sendFrame(player, payload, extra or {})
		return
	end
	Server.sendMatchInfo(player, kind, payload, extra)
end

local function connectedPlayers(match: Match): { [number]: Player }
	local out: { [number]: Player } = {}
	for userId, player in pairs(match.players) do
		if player.Parent == Players then
			out[userId] = player
		end
	end
	return out
end

local function isDevAllowed(player: Player): boolean
	return RunService:IsStudio() or DEV_ALLOWLIST[player.UserId] == true
end

-- ---------------------------------------------------------------------------
-- Criação
-- ---------------------------------------------------------------------------

export type StartRequest = {
	players: { Player },
	-- campanha: a fase manda em mapa, ondas, vida e sucata. Treino continua indo por mapa solto.
	levelId: string?,
	mapId: string?,
	difficulty: Types.Difficulty,
	mode: Types.MatchMode,
	partyId: string?,
}

function MatchService.start(request: StartRequest): (Match?, string?)
	if #request.players == 0 or #request.players > Balance.partyMax then
		return nil, "INVALID_STATE"
	end
	local level = if request.levelId then Catalog.getLevel(request.levelId) else nil
	if request.mode ~= "training" and not level then
		return nil, "INVALID_STATE" -- toda partida de campanha nasce de uma fase
	end
	local mapId = if level then level.mapId else request.mapId
	if not mapId or not Catalog.getMap(mapId) or not Catalog.getDifficulty(request.difficulty) then
		return nil, "INVALID_STATE"
	end
	local participants: { Types.Participant } = {}
	for _, player in ipairs(request.players) do
		if playerMatch[player.UserId] then
			return nil, "INVALID_STATE"
		end
		local profile = PlayerDataService.get(player)
		local loadout = if profile then table.clone(profile.loadout) else Catalog.starterTowerIds()
		PlayerDataService.markOnboarding(player, TelemetryService.ONBOARDING.firstMatch, "first_match")
		table.insert(participants, {
			userId = player.UserId,
			connected = true,
			active = true,
			ready = false,
			speedVote = 1,
			disconnectedAt = nil,
			loadout = loadout,
			displayName = player.DisplayName,
		})
	end
	local matchId = HttpService:GenerateGUID(false)
	-- Retomada e Reforço valem na campanha, fora da fase do guia (a primeira fase ensina o jogo e
	-- não é lugar de oferta) e fora do treino.
	local monetized = request.mode == "normal" and level ~= nil and not level.intro
	local state = Simulation.new({
		matchId = matchId,
		configVersion = Balance.version .. "+" .. Balance.checksum:sub(1, 8),
		mode = request.mode,
		mapId = mapId,
		difficulty = request.difficulty,
		participants = participants,
		seed = math.random(1, 2 ^ 30),
		levelId = if level then level.id else nil,
		waves = if level then level.waves else nil,
		hpScale = if level then level.hpScale else nil,
		startingCash = if level then level.startingCash else nil,
		manualWaveStart = if level then level.manualWaveStart else nil,
		bossHpScale = if level then level.bossHpScale else nil,
		retryAllowed = monetized and Products.retryEnabled,
		supportAllowed = monetized and Products.supportEnabled,
	})
	local now = os.clock()
	local match: Match = {
		id = matchId,
		state = state,
		players = {},
		explicitlyLeft = {},
		accumulator = 0,
		lastFrameAt = now,
		lastFullAt = now,
		pendingEvents = {},
		needFull = true,
		absentSince = {},
		allAbsentSince = nil,
		settled = false,
		settling = false,
		resultAt = nil,
		rematchReady = {},
		overloadCount = 0,
		overloadWindowStart = now,
		createdAt = now,
		outcomes = nil,
		partyId = request.partyId,
		retryDeadline = nil,
		retryDeclined = {},
	}
	for _, player in ipairs(request.players) do
		match.players[player.UserId] = player
		playerMatch[player.UserId] = matchId
	end
	matches[matchId] = match
	if request.mode == "normal" then
		RewardService.registerPending(request.players, matchId)
	end
	for _, player in ipairs(request.players) do
		send(player, "match", Snapshot.build(state, player.UserId, true), {})
		TelemetryService.funnel(player, "match", 1, "match_start", matchId)
	end
	TelemetryService.log("match_start", {
		matchId = matchId,
		mode = request.mode,
		mapId = request.mapId,
		difficulty = request.difficulty,
		partySize = #request.players,
	})
	return match, nil
end

function MatchService.getMatchOf(player: Player): Match?
	local id = playerMatch[player.UserId]
	return if id then matches[id] else nil
end

function MatchService.getMatch(matchId: string): Match?
	return matches[matchId]
end

function MatchService.isInMatch(userId: number): boolean
	return playerMatch[userId] ~= nil
end

-- ---------------------------------------------------------------------------
-- Resultado, revanche e encerramento
-- ---------------------------------------------------------------------------

local function settle(match: Match)
	if match.settled or match.settling then
		return
	end
	match.settling = true
	match.resultAt = os.clock()
	local state = match.state
	local connected = connectedPlayers(match)
	for _, player in pairs(connected) do
		send(player, "result", { status = "saving", result = state.result, stats = state.stats })
	end
	task.spawn(function()
		local outcomes = RewardService.settle(state, connected)
		match.outcomes = outcomes
		match.settled = true
		match.settling = false
		for userId, player in pairs(connectedPlayers(match)) do
			send(player, "result", {
				status = "done",
				result = state.result,
				stats = state.stats,
				outcome = outcomes[userId],
				profile = PlayerDataService.clientView(player),
			})
			TelemetryService.funnel(player, "match", 2, "match_end", match.id)
			local result = state.result
			if result and result.outcome == "won" and result.levelId then
				local steps = TelemetryService.ONBOARDING
				local byLevel = { ["1"] = steps.level1Won, ["2"] = steps.level2Won, ["3"] = steps.level3Won }
				local step = byLevel[result.levelId]
				if step then
					PlayerDataService.markOnboarding(player, step, "level" .. result.levelId .. "_won")
				end
			end
			local profile = PlayerDataService.get(player)
			if profile and Progression.levelOf(profile.xp) >= 3 then
				PlayerDataService.markOnboarding(player, TelemetryService.ONBOARDING.accountLevel3, "account_level_3")
			end
			local outcome = outcomes[userId]
			if outcome and outcome.buttons > 0 and profile then
				TelemetryService.economy(player, true, "buttons", outcome.buttons, profile.buttons, "Gameplay", "match")
			end
		end
	end)
end

local function closeMatch(match: Match)
	matches[match.id] = nil
	for _, p in ipairs(match.state.participants) do
		if playerMatch[p.userId] == match.id then
			playerMatch[p.userId] = nil
		end
	end
	for _, player in pairs(connectedPlayers(match)) do
		send(player, "left", { matchId = match.id })
		if onPlayerFreed then
			onPlayerFreed(player)
		end
	end
	TelemetryService.log("match_closed", { matchId = match.id, phase = match.state.phase })
end

local function tryRematch(match: Match)
	local connected = connectedPlayers(match)
	local ready: { Player } = {}
	local total = 0
	for userId, player in pairs(connected) do
		total += 1
		if match.rematchReady[userId] then
			table.insert(ready, player)
		end
	end
	for _, player in pairs(connected) do
		send(player, "rematch", { ready = #ready, total = total })
	end
	if total > 0 and #ready == total and onRematch then
		local players = ready
		closeMatch(match)
		onRematch(match, players)
	end
end

-- ---------------------------------------------------------------------------
-- Presença
-- ---------------------------------------------------------------------------

function MatchService.onPlayerRemoving(player: Player)
	local match = MatchService.getMatchOf(player)
	if not match then
		return
	end
	match.players[player.UserId] = nil
	match.absentSince[player.UserId] = os.clock()
	local events = Simulation.setParticipantPresence(match.state, player.UserId, false, true)
	for _, e in ipairs(events) do
		table.insert(match.pendingEvents, e)
	end
	if next(connectedPlayers(match)) == nil then
		match.allAbsentSince = os.clock()
	end
	match.rematchReady[player.UserId] = nil
	if Simulation.isTerminal(match.state) then
		tryRematch(match)
	end
end

function MatchService.onPlayerAdded(player: Player)
	local matchId = playerMatch[player.UserId]
	if not matchId then
		return
	end
	local match = matches[matchId]
	if not match then
		playerMatch[player.UserId] = nil
		return
	end
	match.players[player.UserId] = player
	match.absentSince[player.UserId] = nil
	match.allAbsentSince = nil
	local events = Simulation.setParticipantPresence(match.state, player.UserId, true, true)
	for _, e in ipairs(events) do
		table.insert(match.pendingEvents, e)
	end
	send(player, "match", Snapshot.build(match.state, player.UserId, true), { rejoin = true })
	if Simulation.isTerminal(match.state) and match.settled then
		send(player, "result", {
			status = "done",
			result = match.state.result,
			stats = match.state.stats,
			outcome = match.outcomes and match.outcomes[player.UserId],
		})
	end
	TelemetryService.log("match_rejoin", { matchId = matchId, userId = player.UserId })
end

local function leaveMatch(match: Match, player: Player)
	match.players[player.UserId] = nil
	match.explicitlyLeft[player.UserId] = true
	match.rematchReady[player.UserId] = nil
	playerMatch[player.UserId] = nil
	local events = Simulation.setParticipantPresence(match.state, player.UserId, false, false)
	for _, e in ipairs(events) do
		table.insert(match.pendingEvents, e)
	end
	send(player, "left", { matchId = match.id })
	if onPlayerFreed then
		onPlayerFreed(player)
	end
	local anyRemaining = false
	for _, p in ipairs(match.state.participants) do
		if not match.explicitlyLeft[p.userId] then
			anyRemaining = true
		end
	end
	if not anyRemaining and not Simulation.isTerminal(match.state) then
		local abandonEvents = Simulation.abandon(match.state)
		for _, e in ipairs(abandonEvents) do
			table.insert(match.pendingEvents, e)
		end
	end
	if Simulation.isTerminal(match.state) then
		tryRematch(match)
	end
end

-- ---------------------------------------------------------------------------
-- Comandos
-- ---------------------------------------------------------------------------

local function result(ok: boolean, code: string?, extra: { [string]: any }?): { [string]: any }
	local r: { [string]: any } = { ok = ok, errorCode = code }
	if extra then
		for k, v in pairs(extra) do
			r[k] = v
		end
	end
	return r
end

local function fromSim(cr: Types.CommandResult): { [string]: any }
	return { ok = cr.ok, errorCode = cr.errorCode, balance = cr.balance, revision = cr.revision, entityId = cr.entityId }
end

local function pushEvents(match: Match, events: { Types.SimEvent })
	for _, e in ipairs(events) do
		table.insert(match.pendingEvents, e)
		if
			e.kind == "towerPlaced"
			or e.kind == "towerSold"
			or e.kind == "towerUpgraded"
			or e.kind == "circuitChanged"
			-- torre desligada por chefe (Boneco de Poeira, Meia): o cliente precisa da torre nova já
			or (e.kind == "bossAbility" and e.towerIds ~= nil and #e.towerIds > 0)
		then
			match.needFull = true
		end
	end
end

function MatchService.handle(player: Player, action: string, payload: { [string]: any }): { [string]: any }
	local match = MatchService.getMatchOf(player)
	if not match then
		return result(false, Protocol.ERROR.NOT_IN_MATCH)
	end
	if payload.matchId ~= nil and payload.matchId ~= match.id then
		return result(false, Protocol.ERROR.INVALID_STATE)
	end
	local state = match.state
	local userId = player.UserId

	if action == "PlaceTower" then
		local profile = PlayerDataService.get(player)
		local unlocked = if profile then profile.ownedTowerIds else Catalog.starterTowerIds()
		-- Reforço: a ficha é conferida antes e só é gasta se a torre de fato entrou em campo
		local free = payload.support == true
		if free then
			if not profile or profile.inventory.support < 1 then
				return result(false, Protocol.ERROR.INSUFFICIENT_ITEMS)
			end
			if not Simulation.canUseSupport(state, userId) then
				return result(false, Protocol.ERROR.INVALID_STATE)
			end
		end
		local cr, events = Simulation.placeTower(
			state,
			userId,
			payload.towerId,
			payload.x,
			payload.y,
			{ unlockedTowerIds = unlocked, free = free }
		)
		pushEvents(match, events)
		if cr.ok then
			TelemetryService.funnel(player, "match", 3, "first_tower", match.id)
			PlayerDataService.markOnboarding(player, TelemetryService.ONBOARDING.firstTower, "first_tower")
			if free then
				local consumed = false
				PlayerDataService.mutate(player, function(p: Types.Profile)
					consumed = ProfileSchema.consumeItem(p, "support")
				end)
				task.spawn(function()
					PlayerDataService.save(player, false)
				end)
				local after = PlayerDataService.get(player)
				TelemetryService.economy(
					player,
					false,
					"support",
					1,
					if after then after.inventory.support else 0,
					"Gameplay",
					payload.towerId
				)
				TelemetryService.log(
					"support_used",
					{ userId = userId, matchId = match.id, tower = payload.towerId, consumed = consumed }
				)
				local body = fromSim(cr)
				body.profile = PlayerDataService.clientView(player)
				return body
			end
		end
		return fromSim(cr)
	elseif action == "UseRetry" then
		return MatchService.useRetry(match, player)
	elseif action == "DeclineRetry" then
		if state.phase ~= "RetryDecision" then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		match.retryDeclined[userId] = true
		TelemetryService.log("retry_declined", { userId = userId, matchId = match.id, wave = state.lostAtWave })
		return result(true)
	elseif action == "UpgradeTower" then
		local cr, events = Simulation.upgradeTower(state, userId, payload.entityId, payload.nextState)
		pushEvents(match, events)
		return fromSim(cr)
	elseif action == "SellTower" then
		local cr, events = Simulation.sellTower(state, userId, payload.entityId)
		pushEvents(match, events)
		return fromSim(cr)
	elseif action == "SetTarget" then
		local cr = Simulation.setTarget(state, userId, payload.entityId, payload.mode)
		match.needFull = true
		return fromSim(cr)
	elseif action == "CastPulse" then
		local cr, events = Simulation.castPulse(state, userId)
		pushEvents(match, events)
		return fromSim(cr)
	elseif action == "SetReady" then
		return fromSim(Simulation.setReady(state, userId, payload.ready))
	elseif action == "VoteSpeed" then
		local cr, events = Simulation.voteSpeed(state, userId, payload.value)
		pushEvents(match, events)
		return fromSim(cr)
	elseif action == "RequestSnapshot" then
		match.needFull = true
		return result(true, nil, { snapshot = Snapshot.build(state, userId, true) })
	elseif action == "LeaveMatch" then
		leaveMatch(match, player)
		return result(true)
	elseif action == "TrainingSpawn" then
		return fromSim(Simulation.trainingSpawn(state, payload.enemyId, payload.count))
	elseif action == "TrainingClear" then
		local cr, events = Simulation.trainingClear(state)
		pushEvents(match, events)
		match.needFull = true
		return fromSim(cr)
	elseif action == "Rematch" then
		if not Simulation.isTerminal(state) then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		match.rematchReady[userId] = payload.ready == true
		tryRematch(match)
		return result(true)
	elseif action == "DevCommand" then
		if not isDevAllowed(player) then
			return result(false, Protocol.ERROR.INVALID_STATE)
		end
		local command = payload.command
		local arg = payload.arg
		if command == "grantScrap" and typeof(arg) == "number" and (state.mode :: string) ~= "training" then
			state.wallets[userId] += math.clamp(math.floor(arg), 0, 100000)
			state.revision += 1
			return result(true, nil, { balance = state.wallets[userId] })
		elseif command == "startWave" and typeof(arg) == "number" then
			local cr, events = Simulation.devJumpToWave(state, arg)
			pushEvents(match, events)
			match.needFull = true
			return fromSim(cr)
		elseif command == "killAll" then
			for _, id in ipairs(state.enemyOrder) do
				state.enemies[id].hp = 0
			end
			return result(true)
		elseif command == "setBaseHP" and typeof(arg) == "number" then
			state.baseHP = math.clamp(math.floor(arg), 0, Balance.baseHP)
			return result(true)
		elseif command == "summary" then
			return result(true, nil, {
				telemetry = TelemetryService.recent(30),
				phase = state.phase,
				wave = state.waveIndex,
				simTime = state.simTime,
				enemies = #state.enemyOrder,
				towers = #state.towerOrder,
			})
		end
		return result(false, Protocol.ERROR.BAD_REQUEST)
	end
	return result(false, Protocol.ERROR.BAD_REQUEST)
end

-- ---------------------------------------------------------------------------
-- Loop
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Retomada
-- ---------------------------------------------------------------------------

-- Usa uma Retomada do próprio inventário. Uma aplicação só vence a disputa: o segundo pedido
-- encontra a partida fora da decisão e não gasta nada.
function MatchService.useRetry(match: Match, player: Player): { [string]: any }
	local state = match.state
	if not Simulation.canRetry(state) then
		return result(false, Protocol.ERROR.INVALID_STATE)
	end
	if Simulation.getParticipant(state, player.UserId) == nil then
		return result(false, Protocol.ERROR.NOT_OWNER)
	end
	local profile = PlayerDataService.get(player)
	if not profile or profile.inventory.retry < 1 then
		return result(false, Protocol.ERROR.INSUFFICIENT_ITEMS)
	end
	local consumed = false
	PlayerDataService.mutate(player, function(p: Types.Profile)
		consumed = ProfileSchema.consumeItem(p, "retry")
	end)
	if not consumed then
		return result(false, Protocol.ERROR.INSUFFICIENT_ITEMS)
	end
	local wave = state.lostAtWave
	local cr, events = Simulation.applyRetry(state)
	if not cr.ok then
		-- não deveria acontecer (conferido acima), mas ficha gasta sem efeito volta na hora
		PlayerDataService.mutate(player, function(p: Types.Profile)
			p.inventory.retry += 1
		end)
		TelemetryService.log("retry_compensated", { userId = player.UserId, matchId = match.id })
		return result(false, Protocol.ERROR.INVALID_STATE)
	end
	task.spawn(function()
		PlayerDataService.save(player, false)
	end)
	match.retryDeadline = nil
	match.retryDeclined = {}
	pushEvents(match, events)
	match.needFull = true
	TelemetryService.log("retry_applied", { userId = player.UserId, matchId = match.id, wave = wave })
	local after = PlayerDataService.get(player)
	TelemetryService.economy(player, false, "retry", 1, if after then after.inventory.retry else 0, "Gameplay", "retry")
	local body = fromSim(cr)
	body.profile = PlayerDataService.clientView(player)
	return body
end

-- Alguém abriu a janela de compra durante a decisão: o prazo cresce uma vez (o tempo do Roblox
-- confirmar não pode vencer a partida). Não aparece para o jogador como urgência.
function MatchService.onPurchasePrompt(player: Player)
	local match = MatchService.getMatchOf(player)
	if not match or match.state.phase ~= "RetryDecision" then
		return
	end
	local extended = os.clock() + Balance.shop.retry.promptGraceSeconds
	if (match.retryDeadline or 0) < extended then
		match.retryDeadline = extended
	end
end

-- Decisão da Retomada: prazo em tempo real. Vence o prazo, todos os presentes recusaram ou não
-- sobrou ninguém: derrota definitiva pelo caminho de sempre.
local function updateRetryDecision(match: Match, now: number)
	local state = match.state
	if state.phase ~= "RetryDecision" then
		return
	end
	if not match.retryDeadline then
		match.retryDeadline = now + Balance.shop.retry.decisionSeconds
		TelemetryService.log("retry_offered", { matchId = match.id, wave = state.lostAtWave })
	end
	local anyUndecided = false
	for userId in pairs(connectedPlayers(match)) do
		if not match.retryDeclined[userId] then
			anyUndecided = true
		end
	end
	if not anyUndecided or now >= (match.retryDeadline :: number) then
		local _, events = Simulation.declineRetry(state)
		pushEvents(match, events)
		match.needFull = true
	end
end

-- O guia da primeira fase é visto uma vez só: quando a primeira onda sai, o perfil registra.
local function markIntroSeen(match: Match, events: { Types.SimEvent })
	local levelId = match.state.levelId
	if not levelId then
		return
	end
	local level = Catalog.getLevel(levelId)
	if not level or not level.intro then
		return
	end
	for _, e in ipairs(events) do
		if e.kind == "waveStart" then
			for _, player in pairs(connectedPlayers(match)) do
				PlayerDataService.mutate(player, function(profile: Types.Profile)
					profile.campaignIntroSeen = true
				end)
				PlayerDataService.markOnboarding(player, TelemetryService.ONBOARDING.firstWave, "first_wave")
			end
			return
		end
	end
end

local function stepMatch(match: Match, dt: number)
	local state = match.state
	if Simulation.isTerminal(state) then
		return
	end
	match.accumulator += dt * state.speedMultiplier
	local steps = 0
	while match.accumulator >= STEP and steps < MAX_STEPS_PER_HEARTBEAT do
		local events = Simulation.step(state)
		markIntroSeen(match, events)
		pushEvents(match, events)
		match.accumulator -= STEP
		steps += 1
		if Simulation.isTerminal(state) then
			break
		end
	end
	if match.accumulator > MAX_ACCUMULATOR then
		match.accumulator = MAX_ACCUMULATOR
		local now = os.clock()
		if now - match.overloadWindowStart > OVERLOAD_WINDOW then
			match.overloadWindowStart = now
			match.overloadCount = 0
		end
		match.overloadCount += 1
		TelemetryService.log("sim_overload", { matchId = match.id, count = match.overloadCount })
		if match.overloadCount >= OVERLOAD_LIMIT and state.speedMultiplier == 2 then
			local events = {}
			Simulation.forceSpeed(state, 1, events)
			pushEvents(match, events)
			match.overloadCount = 0
		end
	end
end

local function sendFrames(match: Match, now: number)
	if now - match.lastFrameAt < FRAME_INTERVAL then
		return
	end
	match.lastFrameAt = now
	local full = match.needFull or (now - match.lastFullAt >= FULL_INTERVAL)
	if full then
		match.lastFullAt = now
		match.needFull = false
	end
	local events = match.pendingEvents
	match.pendingEvents = {}
	for userId, player in pairs(connectedPlayers(match)) do
		send(player, "frame", Snapshot.build(match.state, userId, full), events)
	end
end

local function updatePresence(match: Match, now: number)
	for userId, since in pairs(match.absentSince) do
		if now - since >= ABSENT_INACTIVE_SECONDS then
			local participant = Simulation.getParticipant(match.state, userId)
			if participant and participant.active then
				pushEvents(match, Simulation.setParticipantPresence(match.state, userId, false, false))
			end
		end
	end
	local allAbsent = match.allAbsentSince
	if allAbsent and now - allAbsent >= ABANDON_SECONDS and not Simulation.isTerminal(match.state) then
		pushEvents(match, Simulation.abandon(match.state))
	end
end

local function heartbeat(dt: number)
	local now = os.clock()
	for _, match in pairs(matches) do
		updatePresence(match, now)
		updateRetryDecision(match, now)
		stepMatch(match, dt)
		if Simulation.isTerminal(match.state) then
			settle(match)
			if match.settled then
				local resultAt = match.resultAt or now
				if next(connectedPlayers(match)) == nil or now - resultAt >= CLOSE_AFTER_RESULT_SECONDS then
					closeMatch(match)
					continue
				end
			end
		end
		sendFrames(match, now)
	end
end

-- Solta o jogador da partida em que estiver. Chamado antes de começar outra: pedir uma fase
-- nova é, por definição, sair da anterior. Sem isto, um "sair" que se perdeu no caminho deixava
-- o jogador preso à partida antiga e toda fase seguinte recusava com "ação indisponível".
function MatchService.releasePlayer(player: Player): boolean
	local match = MatchService.getMatchOf(player)
	if not match then
		return false
	end
	leaveMatch(match, player)
	return true
end

-- ---------------------------------------------------------------------------
-- Atalhos de teste (console Cmdr)
-- ---------------------------------------------------------------------------
-- Chamados de dentro do servidor, pelo console, e não pela rede: quem digita já está autenticado
-- como jogador do servidor. Mesmo assim passam por `isDevAllowed`, porque a regra de quem pode
-- trapacear é uma só — o console é apenas mais uma porta para ela.
--
-- Todos devolvem (deu certo, recado): o recado é o que aparece escrito no console.

-- Exposto para o console usar a mesma regra de permissão do DevCommand.
function MatchService.isDevAllowed(player: Player): boolean
	return isDevAllowed(player)
end

local function cheatMatch(player: Player): (Match?, string)
	if not isDevAllowed(player) then
		return nil, "Console de teste indisponível para este jogador."
	end
	local match = MatchService.getMatchOf(player)
	if not match then
		return nil, "Você não está em partida."
	end
	return match, ""
end

function MatchService.cheatSetScrap(player: Player, amount: number): (boolean, string)
	local match, why = cheatMatch(player)
	if not match then
		return false, why
	end
	local state = match.state
	if (state.mode :: string) == "training" then
		return false, "No treino a sucata já é infinita."
	end
	local value = math.clamp(math.floor(amount), 0, 1000000)
	state.wallets[player.UserId] = value
	state.revision += 1
	match.needFull = true
	return true, string.format("Sucata de %s: %d.", player.Name, value)
end

function MatchService.cheatSetBaseHP(player: Player, amount: number): (boolean, string)
	local match, why = cheatMatch(player)
	if not match then
		return false, why
	end
	local state = match.state
	local value = math.clamp(math.floor(amount), 0, Balance.baseHP)
	state.baseHP = value
	state.revision += 1
	match.needFull = true
	-- Zerar a vida não encerra aqui: o passo seguinte da simulação é que declara a derrota,
	-- pelo mesmo caminho de sempre.
	return true, string.format("Vida do Farol: %d / %d.", value, Balance.baseHP)
end

function MatchService.cheatFinish(player: Player, outcome: "won" | "lost", stars: number?): (boolean, string)
	local match, why = cheatMatch(player)
	if not match then
		return false, why
	end
	local cr, events = Simulation.devFinish(match.state, outcome, stars)
	if not cr.ok then
		return false, "A partida já tinha terminado."
	end
	pushEvents(match, events)
	match.needFull = true
	local result = match.state.result
	if outcome == "won" then
		return true, string.format("Vitória forçada com %d estrela(s).", if result then result.stars else 0)
	end
	return true, "Derrota forçada."
end

-- Fichas e XP de teste: vão para o perfil pelo mesmo caminho do jogo, só pulam a compra.
function MatchService.cheatGrantItem(player: Player, item: string, amount: number): (boolean, string)
	if not isDevAllowed(player) then
		return false, "Console de teste indisponível para este jogador."
	end
	if item ~= "retry" and item ~= "support" then
		return false, "Item desconhecido (use retry ou support)."
	end
	local value = math.clamp(math.floor(amount), -1000, 1000)
	local ok = PlayerDataService.mutate(player, function(p: Types.Profile)
		p.inventory[item :: Types.ItemId] = math.max(p.inventory[item :: Types.ItemId] + value, 0)
	end)
	if not ok then
		return false, "Perfil indisponível."
	end
	Server.sendLobby(player, "profile", PlayerDataService.clientView(player))
	local profile = PlayerDataService.get(player) :: Types.Profile
	return true, string.format("%s agora tem %d de %s.", player.Name, profile.inventory[item :: Types.ItemId], item)
end

function MatchService.cheatAddXp(player: Player, amount: number): (boolean, string)
	if not isDevAllowed(player) then
		return false, "Console de teste indisponível para este jogador."
	end
	local outcome: Progression.XpOutcome? = nil
	local ok = PlayerDataService.mutate(player, function(p: Types.Profile)
		outcome = Progression.addXp(p, math.clamp(math.floor(amount), 0, 1000000))
	end)
	if not ok or not outcome then
		return false, "Perfil indisponível."
	end
	Server.sendLobby(player, "profile", PlayerDataService.clientView(player))
	local out = outcome :: Progression.XpOutcome
	return true, string.format("+%d XP: nível %d -> %d.", out.xpGained, out.levelBefore, out.levelAfter)
end

function MatchService.init(callbacks: { onPlayerFreed: (Player) -> (), onRematch: (Match, { Player }) -> () })
	onPlayerFreed = callbacks.onPlayerFreed
	onRematch = callbacks.onRematch
	RunService.Heartbeat:Connect(heartbeat)
end

function MatchService.activeMatchCount(): number
	local n = 0
	for _ in pairs(matches) do
		n += 1
	end
	return n
end

return MatchService
