--!strict
-- Simulação autoritativa e pura da partida. Não depende de serviços Roblox.
-- O servidor executa Simulation.step em passos fixos de 0,05 s; o cliente só apresenta o estado.
local Types = require(script.Parent.Parent.Types)
local Balance = require(script.Parent.Parent.Config.Balance)
local Catalog = require(script.Parent.Parent.Config.Catalog)
local Grid = require(script.Parent.Parent.Math.Grid)
local Path = require(script.Parent.Parent.Math.Path)
local Combat = require(script.Parent.Parent.Rules.Combat)
local Circuits = require(script.Parent.Parent.Rules.Circuits)
local Rewards = require(script.Parent.Parent.Rules.Rewards)
local Stars = require(script.Parent.Parent.Rules.Stars)
local Progression = require(script.Parent.Parent.Rules.Progression)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local Simulation = {}

Simulation.STEP = 1 / Balance.tickRate -- 0,05 s
Simulation.DUST_FACTOR = 0.75
Simulation.BOSS_DELAY_AFTER_GROUPS = 2
Simulation.CASULO_CHILD_HP = 12
Simulation.CASULO_CHILD_SPEED = 1.6
Simulation.CASULO_CHILD_LEAK = 1
Simulation.PULSE_SOURCE_ID = 0
Simulation.MAX_ENEMIES = 250

type MapEntry = typeof(require(script.Parent.Parent.Config.Maps)[1])

local pathCache: { [string]: Path.PathData } = {}
local blockedCache: { [string]: { [number]: boolean } } = {}

local function getMap(mapId: string): MapEntry
	local map = Catalog.getMap(mapId)
	assert(map, "mapa desconhecido: " .. tostring(mapId))
	return map
end

local function getPath(mapId: string): Path.PathData
	local cached = pathCache[mapId]
	if cached then
		return cached
	end
	local built = Path.build(getMap(mapId).path)
	pathCache[mapId] = built
	return built
end

local function getBlocked(mapId: string): { [number]: boolean }
	local cached = blockedCache[mapId]
	if cached then
		return cached
	end
	local set = Grid.cellSet(getMap(mapId).blocked)
	blockedCache[mapId] = set
	return set
end

Simulation.getPath = getPath
Simulation.getBlocked = getBlocked

-- Torre desligada por chefe (Boneco de Poeira, Meia): não atira, não recarrega e não dá aura.
local function isDisabled(state: Types.MatchState, tower: Types.Tower): boolean
	return tower.disabledUntil > state.simTime
end
Simulation.isDisabled = isDisabled

local function newStats(): Types.PlayerMatchStats
	return { damage = 0, slowSeconds = 0, supportBonusDamage = 0, towersPlaced = 0, commandsIssued = 0 }
end

local function event(state: Types.MatchState, kind: string, fields: { [string]: any }?): Types.SimEvent
	local e: any = { kind = kind, simTime = state.simTime }
	if fields then
		for k, v in pairs(fields) do
			e[k] = v
		end
	end
	return e
end

-- ---------------------------------------------------------------------------
-- Criação
-- ---------------------------------------------------------------------------

function Simulation.new(config: Types.MatchConfig): Types.MatchState
	local map = getMap(config.mapId)
	local path = getPath(config.mapId)
	local difficulty = Catalog.getDifficulty(config.difficulty)
	assert(difficulty, "dificuldade desconhecida")
	local n = #config.participants
	assert(n >= 1 and n <= Balance.partyMax, "número de participantes inválido")
	local coop = 1 + Balance.coopAdditionalHPPerPlayer * (n - 1)
	local participants: { Types.Participant } = {}
	local order: { number } = {}
	local wallets: { [number]: number } = {}
	local stats: { [number]: Types.PlayerMatchStats } = {}
	local active: { [number]: { [string]: number } } = {}
	-- a fase manda na sucata inicial; fora da campanha vale o padrão do balanceamento
	local startingCash = config.startingCash or Balance.startingCash
	for _, p in ipairs(config.participants) do
		table.insert(participants, {
			userId = p.userId,
			connected = p.connected,
			active = p.active,
			ready = false,
			speedVote = 1,
			disconnectedAt = nil,
			loadout = table.clone(p.loadout),
			displayName = p.displayName,
		})
		table.insert(order, p.userId)
		wallets[p.userId] = startingCash
		stats[p.userId] = newStats()
		active[p.userId] = {}
	end
	table.sort(order)
	local totalWaves = math.clamp(config.waves or #Balance.waves, 1, #Balance.waves)
	if config.mode == "training" then
		totalWaves = 0
	end
	-- Só a primeira fase espera o jogador chamar cada onda; nas outras o cronômetro corre.
	local manualWaveStart = config.manualWaveStart == true
	local state: Types.MatchState = {
		matchId = config.matchId,
		configVersion = config.configVersion,
		mode = config.mode,
		mapId = config.mapId,
		difficulty = config.difficulty,
		seed = config.seed,
		participants = participants,
		participantOrder = order,
		phase = if config.mode == "training" then "Wave" else "Preparation",
		waveIndex = 0,
		totalWaves = totalWaves,
		baseHP = Balance.baseHP,
		simTime = 0,
		speedMultiplier = 1,
		phaseEndsAt = if manualWaveStart then math.huge else Balance.preparationSeconds,
		enemies = {},
		enemyOrder = {},
		towers = {},
		towerOrder = {},
		cellOccupancy = {},
		wallets = wallets,
		nextEntityId = 1,
		waveRuntime = {
			groupIndex = 0,
			spawnedInGroup = 0,
			nextSpawnAt = 0,
			allGroupsSpawned = false,
			bossScheduledAt = nil,
			bossSpawned = false,
			waveStartedAt = 0,
		},
		pulseReadyAt = if Balance.pulse.startsCharged then 0 else Balance.pulse.cooldown,
		bountyCursor = 1,
		stats = stats,
		commonHpFactor = map.hpMultiplier * difficulty.hp * coop * (config.hpScale or 1),
		bossHpFactor = difficulty.hp * coop * (config.hpScale or 1) * (config.bossHpScale or 1),
		coopFactor = coop,
		pathLength = path.totalLength,
		revision = 0,
		result = nil,
		trainingUnlockAll = config.trainingUnlockAll == true or config.mode == "training",
		firstShotAt = nil,
		activeSecondsByUserTower = active,
		trainingQueue = {},
		levelId = config.levelId,
		manualWaveStart = manualWaveStart,
		campaignStats = {
			damageTaken = 0,
			towersBuilt = 0,
			towerIds = {},
			wavesRushed = 0,
			wavesTotal = totalWaves,
			towersSold = 0,
			circuitsActive = 0,
		},
		lastSupportPulseAt = {},
		bossHpScale = config.bossHpScale,
		checkpoint = nil,
		retryAllowed = config.retryAllowed == true and config.mode == "normal",
		retryUsed = false,
		lostAtWave = 0,
		supportAllowed = config.supportAllowed == true and config.mode == "normal",
		supportUsedBy = {},
		assisted = false,
		pathClouds = {},
	}
	return state
end

function Simulation.clone(state: Types.MatchState): Types.MatchState
	return TableUtil.deepClone(state)
end

-- ---------------------------------------------------------------------------
-- Consultas
-- ---------------------------------------------------------------------------

function Simulation.getParticipant(state: Types.MatchState, userId: number): Types.Participant?
	for _, p in ipairs(state.participants) do
		if p.userId == userId then
			return p
		end
	end
	return nil
end

-- Retomada: pode repetir a onda perdida? Uma vez por partida, e só com foto do início da onda.
function Simulation.canRetry(state: Types.MatchState): boolean
	return state.phase == "RetryDecision" and state.retryAllowed and not state.retryUsed and state.checkpoint ~= nil
end

-- Reforço: uma torre de graça por jogador, só na preparação (antes da primeira onda).
function Simulation.canUseSupport(state: Types.MatchState, userId: number): boolean
	return state.supportAllowed
		and state.phase == "Preparation"
		and state.supportUsedBy[userId] ~= true
		and Simulation.getParticipant(state, userId) ~= nil
end

function Simulation.isTerminal(state: Types.MatchState): boolean
	local p = state.phase
	return p == "Won" or p == "Lost" or p == "Abandoned" or p == "Closed" or p == "RewardPending"
end

function Simulation.isCombatPhase(state: Types.MatchState): boolean
	local p = state.phase
	return p == "Preparation" or p == "Wave" or p == "Intermission"
end

function Simulation.towerLimitPerPlayer(state: Types.MatchState): number
	return Catalog.towerLimitForPartySize(#state.participants)
end

function Simulation.countTowersOwned(state: Types.MatchState, userId: number, defId: string?): number
	local n = 0
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		if t.ownerUserId == userId and (defId == nil or t.defId == defId) then
			n += 1
		end
	end
	return n
end

function Simulation.aliveEnemyCount(state: Types.MatchState): number
	return #state.enemyOrder
end

local function towerList(state: Types.MatchState): { Types.Tower }
	local list = {}
	for _, id in ipairs(state.towerOrder) do
		table.insert(list, state.towers[id])
	end
	return list
end
Simulation.towerList = towerList

-- Onda da tabela global com os grupos do mapa (mapGroups) acrescentados no fim: é assim que o
-- Floquinho só aparece no Inverno e a Migalha só na Cozinha, sem uma tabela de ondas por mapa.
local waveCache: { [string]: { [number]: Types.WaveDef } } = {}

function Simulation.waveFor(mapId: string, index: number): Types.WaveDef?
	local base = Balance.waves[index]
	if not base then
		return nil
	end
	local perMap = waveCache[mapId]
	if not perMap then
		perMap = {}
		waveCache[mapId] = perMap
	end
	local cached = perMap[index]
	if cached then
		return cached
	end
	local def: Types.WaveDef = base
	local map = Catalog.getMap(mapId)
	if map and #map.mapGroups > 0 then
		local groups = table.clone(base.groups)
		for _, g in ipairs(map.mapGroups) do
			if index >= g.fromWave then
				local count = g.count + math.floor(g.perWave * (index - g.fromWave) + 1e-9)
				table.insert(groups, { enemy = g.enemy, count = count })
			end
		end
		if #groups > #base.groups then
			def = {
				wave = base.wave,
				groups = groups,
				spawnInterval = base.spawnInterval,
				groupGap = base.groupGap,
				bossAfterGroups = base.bossAfterGroups,
				income = base.income,
			}
		end
	end
	perMap[index] = def
	return def
end

-- A fase usa as N primeiras ondas da tabela global; passar do fim da fase é fim de partida.
function Simulation.getWaveDef(state: Types.MatchState, index: number): Types.WaveDef?
	if index > state.totalWaves then
		return nil
	end
	return Simulation.waveFor(state.mapId, index)
end

-- ---------------------------------------------------------------------------
-- Circuitos
-- ---------------------------------------------------------------------------

local function recomputeCircuits(state: Types.MatchState, events: { Types.SimEvent })
	local assignments = Circuits.assign(towerList(state), Catalog.getCircuitFor)
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		local a = assignments[id]
		local newPartner = if a then a.partnerId else nil
		local newCircuit = if a then a.circuitId else nil
		if t.circuitPartnerId ~= newPartner or t.circuitId ~= newCircuit then
			t.circuitPartnerId = newPartner
			t.circuitId = newCircuit
			table.insert(
				events,
				event(state, "circuitChanged", { towerId = id, partnerId = newPartner, circuitId = newCircuit })
			)
		end
	end
end

local function circuitBonusFor(tower: Types.Tower, effect: string): number
	if not tower.circuitId then
		return 0
	end
	for _, c in ipairs(Balance.circuits) do
		if c.id == tower.circuitId and c.effect == effect then
			return c.value
		end
	end
	return 0
end

-- ---------------------------------------------------------------------------
-- Inimigos
-- ---------------------------------------------------------------------------

type SpawnOverrides = { hp: number?, speed: number?, leak: number?, bounty: number?, isSummon: boolean? }

local function spawnEnemy(
	state: Types.MatchState,
	defId: string,
	s: number,
	events: { Types.SimEvent },
	overrides: SpawnOverrides?
): Types.Enemy?
	local difficulty = Catalog.getDifficulty(state.difficulty) :: Types.DifficultyDef
	local ov: SpawnOverrides = overrides or {}
	local enemyDef = Catalog.getEnemy(defId)
	local bossDef = Catalog.getBoss(defId)
	local id = state.nextEntityId
	state.nextEntityId += 1
	local enemy: Types.Enemy
	if enemyDef then
		local hp = if ov.hp then ov.hp else math.ceil(enemyDef.hp * state.commonHpFactor)
		enemy = {
			id = id,
			defId = defId,
			isBoss = false,
			isSummon = ov.isSummon == true,
			hp = hp,
			maxHp = hp,
			s = s,
			baseSpeed = (ov.speed or enemyDef.speed) * difficulty.speed,
			armor = enemyDef.armor,
			energyResistance = enemyDef.energyResistance or 0,
			bounty = if ov.bounty then ov.bounty else enemyDef.bounty,
			leak = if ov.leak then ov.leak else enemyDef.leak,
			alive = true,
			spawnedAt = state.simTime,
			slows = {},
			marks = {},
			lastHealAt = state.simTime,
			bossArmorBonus = 0,
			bossArmorUntil = 0,
			bossNextTelegraphAt = math.huge,
			bossTelegraphing = false,
			bossResolveAt = 0,
			bossTargetCell = nil,
			bossTargetTowerIds = nil,
			bossSoakUntil = 0,
			shreds = {},
			burns = {},
			freezeUntil = 0,
			freezeBonus = 0,
			freezeImmuneUntil = 0,
			pushReadyAt = 0,
			pushedTotal = 0,
			-- a Traça nasce com a esquiva pronta: o primeiro acerto sempre erra
			dodgeReadyAt = state.simTime,
		}
	elseif bossDef then
		local hp = math.ceil(bossDef.hp * state.bossHpFactor)
		enemy = {
			id = id,
			defId = defId,
			isBoss = true,
			isSummon = false,
			hp = hp,
			maxHp = hp,
			s = s,
			baseSpeed = bossDef.speed * difficulty.speed,
			armor = bossDef.armor,
			energyResistance = 0,
			bounty = bossDef.bounty,
			leak = bossDef.leak,
			alive = true,
			spawnedAt = state.simTime,
			slows = {},
			marks = {},
			lastHealAt = state.simTime,
			bossArmorBonus = 0,
			bossArmorUntil = 0,
			bossNextTelegraphAt = state.simTime + bossDef.period,
			bossTelegraphing = false,
			bossResolveAt = 0,
			bossTargetCell = nil,
			bossTargetTowerIds = nil,
			bossSoakUntil = 0,
			shreds = {},
			burns = {},
			freezeUntil = 0,
			freezeBonus = 0,
			freezeImmuneUntil = 0,
			pushReadyAt = 0,
			pushedTotal = 0,
			dodgeReadyAt = math.huge,
		}
	else
		return nil
	end
	state.enemies[id] = enemy
	table.insert(state.enemyOrder, id)
	table.insert(events, event(state, "spawn", { entityId = id, enemyDefId = defId, s = s }))
	return enemy
end

local function removeEnemy(state: Types.MatchState, enemy: Types.Enemy)
	enemy.alive = false
	state.enemies[enemy.id] = nil
	TableUtil.removeValue(state.enemyOrder, enemy.id)
end

-- Morte ou escape cancela um aviso em andamento (nada é resolvido depois da remoção).
-- Efeitos já aplicados em passos anteriores continuam até expirar.
local function cancelTelegraph(state: Types.MatchState, enemy: Types.Enemy, events: { Types.SimEvent })
	if not enemy.bossTelegraphing then
		return
	end
	enemy.bossTelegraphing = false
	enemy.bossNextTelegraphAt = math.huge
	enemy.bossTargetTowerIds = nil
	table.insert(
		events,
		event(state, "bossCancel", { entityId = enemy.id, enemyDefId = enemy.defId, reason = "removed" })
	)
end

-- ---------------------------------------------------------------------------
-- Ondas
-- ---------------------------------------------------------------------------

local function resetReady(state: Types.MatchState)
	for _, p in ipairs(state.participants) do
		p.ready = false
	end
end

local function allActiveReady(state: Types.MatchState): boolean
	local any = false
	for _, p in ipairs(state.participants) do
		if p.active then
			any = true
			if not p.ready then
				return false
			end
		end
	end
	return any
end

-- Bônus por chamar a onda antes do cronômetro: quanto mais tempo sobrava, maior a sucata.
-- Fica aqui (e não no cliente) porque é economia: quem soma no bolso é o servidor.
local function grantEarlyWaveBonus(state: Types.MatchState, index: number, events: { Types.SimEvent })
	if state.mode == "training" or state.phaseEndsAt == math.huge then
		return
	end
	-- a onda repetida pela Retomada não paga o bônus de novo
	local checkpoint = state.checkpoint
	if state.retryUsed and checkpoint and checkpoint.waveIndex == index then
		return
	end
	local remaining = state.phaseEndsAt - state.simTime
	if remaining <= 0 then
		return -- o cronômetro acabou sozinho: não houve adiantamento
	end
	local seconds = math.ceil(remaining)
	local bonus = math.min(seconds * Balance.earlyWaveBonusPerSecond, Balance.earlyWaveBonusMax)
	if bonus <= 0 then
		return
	end
	for _, userId in ipairs(state.participantOrder) do
		state.wallets[userId] += bonus
	end
	state.campaignStats.wavesRushed += 1
	table.insert(events, event(state, "earlyBonus", { wave = index, amount = bonus }))
end

-- Foto do início da onda para a Retomada. Tirada depois do bônus de adiantar e antes do primeiro
-- inimigo, então o que o jogador comprou na preparação já faz parte dela. Nada aqui é de conta:
-- fichas, uso da Retomada e o sinal de ajuda ficam fora e nunca voltam no tempo.
local function takeCheckpoint(state: Types.MatchState, index: number)
	if not state.retryAllowed or state.retryUsed then
		return
	end
	state.checkpoint = {
		waveIndex = index,
		wallets = table.clone(state.wallets),
		towers = TableUtil.deepClone(state.towers),
		towerOrder = table.clone(state.towerOrder),
		cellOccupancy = table.clone(state.cellOccupancy),
		pulseRemaining = math.max(state.pulseReadyAt - state.simTime, 0),
		bountyCursor = state.bountyCursor,
		campaignStats = TableUtil.deepClone(state.campaignStats),
	}
end

local function startWave(state: Types.MatchState, index: number, events: { Types.SimEvent })
	grantEarlyWaveBonus(state, index, events)
	takeCheckpoint(state, index)
	state.waveIndex = index
	state.phase = "Wave"
	state.waveRuntime = {
		groupIndex = 0,
		spawnedInGroup = 0,
		nextSpawnAt = state.simTime,
		allGroupsSpawned = false,
		bossScheduledAt = nil,
		bossSpawned = false,
		waveStartedAt = state.simTime,
	}
	resetReady(state)
	table.insert(events, event(state, "waveStart", { wave = index, phase = "Wave" }))
end

-- Circuitos ligados agora: cada par conta uma vez (as duas torres apontam uma para a outra).
local function countCircuits(state: Types.MatchState): number
	local n = 0
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		if t.circuitPartnerId and t.circuitPartnerId > id then
			n += 1
		end
	end
	return n
end

local function finishMatch(state: Types.MatchState, outcome: "won" | "lost", events: { Types.SimEvent })
	local difficulty = Catalog.getDifficulty(state.difficulty) :: Types.DifficultyDef
	local wavesCompleted = if outcome == "won" then state.totalWaves else math.max(state.waveIndex - 1, 0)
	local buttons = Rewards.buttonsForOutcome(state.mode, outcome, wavesCompleted, difficulty, Balance.rewards)
	local xp = Progression.matchXp(state.mode, outcome, wavesCompleted, state.difficulty, #state.participants)
	state.campaignStats.circuitsActive = countCircuits(state)
	local masteryByUser: { [number]: { [string]: number } } = {}
	for _, p in ipairs(state.participants) do
		local perTower: { [string]: number } = {}
		local activeSeconds = state.activeSecondsByUserTower[p.userId] or {}
		for _, towerId in ipairs(p.loadout) do
			local points =
				Rewards.masteryPoints(state.mode, outcome, wavesCompleted, activeSeconds[towerId] or 0, Balance.rewards)
			if points > 0 then
				perTower[towerId] = points
			end
		end
		masteryByUser[p.userId] = perTower
	end
	-- Estrelas da fase: vitória + os dois objetivos, medidos no que a partida realmente fez.
	local level = if state.levelId then Catalog.getLevel(state.levelId) else nil
	local starOutcome = if level
		then Stars.evaluate(level, outcome == "won", state.campaignStats, state.assisted)
		else { stars = 0, earned = {} }
	state.result = {
		outcome = outcome,
		wavesCompleted = wavesCompleted,
		buttonsPerPlayer = buttons,
		xpPerPlayer = xp,
		assisted = state.assisted,
		eligibleUserIds = table.clone(state.participantOrder),
		masteryByUser = masteryByUser,
		statsByUser = state.stats,
		durationSim = state.simTime,
		levelId = state.levelId,
		stars = starOutcome.stars,
		starsEarned = starOutcome.earned,
		campaignStats = state.campaignStats,
	}
	state.phase = if outcome == "won" then "Won" else "Lost"
	table.insert(events, event(state, "matchEnd", { phase = state.phase, wave = wavesCompleted, amount = buttons }))
end

local function clearEnemies(state: Types.MatchState, events: { Types.SimEvent })
	for _, id in ipairs(table.clone(state.enemyOrder)) do
		local e = state.enemies[id]
		cancelTelegraph(state, e, events)
		removeEnemy(state, e)
		table.insert(events, event(state, "despawn", { entityId = id }))
	end
	state.trainingQueue = {}
end

-- O Farol apagou. Com Retomada disponível a partida congela esperando a decisão (o relógio de
-- decisão é do servidor, em tempo real); sem ela, é derrota na hora.
local function onBaseDestroyed(state: Types.MatchState, events: { Types.SimEvent })
	if state.retryAllowed and not state.retryUsed and state.checkpoint ~= nil then
		clearEnemies(state, events)
		state.lostAtWave = state.waveIndex
		state.phase = "RetryDecision"
		resetReady(state)
		table.insert(events, event(state, "retryOffer", { wave = state.waveIndex, phase = "RetryDecision" }))
		return
	end
	finishMatch(state, "lost", events)
end

-- Coração Remendado: cada Fofo L3B ligado devolve um pouco do Farol ao fim da onda vencida, com
-- teto por onda e nunca acima da vida máxima. Não mexe em "dano levado" (a estrela continua honesta).
local function healBase(state: Types.MatchState, events: { Types.SimEvent })
	if state.mode == "training" or state.baseHP >= Balance.baseHP then
		return
	end
	local heal = 0
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		local stats = Catalog.getStateStats(t.defId, t.state)
		if stats and stats.baseHeal and not isDisabled(state, t) then
			heal += stats.baseHeal
		end
	end
	heal = math.min(heal, Balance.effects.baseHealPerWaveCap, Balance.baseHP - state.baseHP)
	if heal > 0 then
		state.baseHP += heal
		table.insert(events, event(state, "baseHeal", { wave = state.waveIndex, amount = heal }))
	end
end

local function completeWave(state: Types.MatchState, events: { Types.SimEvent })
	healBase(state, events)
	local waveDef = Simulation.getWaveDef(state, state.waveIndex)
	if waveDef then
		local income = Rewards.waveIncome(waveDef)
		for _, userId in ipairs(state.participantOrder) do
			state.wallets[userId] += income
		end
		table.insert(events, event(state, "waveIncome", { wave = state.waveIndex, amount = income }))
	end
	table.insert(events, event(state, "waveEnd", { wave = state.waveIndex }))
	if state.waveIndex >= state.totalWaves then
		finishMatch(state, "won", events)
	else
		state.phase = "Intermission"
		state.phaseEndsAt = if state.manualWaveStart then math.huge else state.simTime + Balance.intermissionSeconds
		resetReady(state)
		table.insert(events, event(state, "phase", { phase = "Intermission" }))
	end
end

local function updateSpawning(state: Types.MatchState, events: { Types.SimEvent })
	-- fila de treino
	if #state.trainingQueue > 0 then
		local remaining = {}
		for _, item in ipairs(state.trainingQueue) do
			if item.at <= state.simTime and #state.enemyOrder < Simulation.MAX_ENEMIES then
				spawnEnemy(state, item.defId, 0, events, nil)
			else
				table.insert(remaining, item)
			end
		end
		state.trainingQueue = remaining
	end
	if state.phase ~= "Wave" or state.mode == "training" then
		return
	end
	local rt = state.waveRuntime
	local waveDef = Simulation.getWaveDef(state, state.waveIndex)
	if not waveDef then
		return
	end
	local map = getMap(state.mapId)
	while not rt.allGroupsSpawned and rt.nextSpawnAt <= state.simTime do
		if #state.enemyOrder >= Simulation.MAX_ENEMIES then
			table.insert(events, event(state, "spawnDeferred", { reason = "max_enemies" }))
			break
		end
		if rt.groupIndex == 0 then
			rt.groupIndex = 1
			rt.spawnedInGroup = 0
		end
		local group = waveDef.groups[rt.groupIndex]
		if not group then
			rt.allGroupsSpawned = true
			break
		end
		spawnEnemy(state, group.enemy, 0, events, nil)
		rt.spawnedInGroup += 1
		if rt.spawnedInGroup >= group.count then
			if rt.groupIndex >= #waveDef.groups then
				rt.allGroupsSpawned = true
				-- o chefe do mapa fecha a onda 20 da tabela e, quando a fase pede, a última onda dela
				local levelBoss = state.bossHpScale ~= nil and state.waveIndex == state.totalWaves
				if waveDef.bossAfterGroups or levelBoss then
					rt.bossScheduledAt = state.simTime + Simulation.BOSS_DELAY_AFTER_GROUPS
				end
			else
				rt.groupIndex += 1
				rt.spawnedInGroup = 0
				rt.nextSpawnAt = state.simTime + waveDef.groupGap
			end
		else
			rt.nextSpawnAt = state.simTime + waveDef.spawnInterval
		end
	end
	if rt.allGroupsSpawned and rt.bossScheduledAt and not rt.bossSpawned and state.simTime >= rt.bossScheduledAt then
		rt.bossSpawned = true
		local boss = spawnEnemy(state, map.boss, 0, events, nil)
		if boss then
			table.insert(events, event(state, "bossSpawn", { entityId = boss.id, enemyDefId = map.boss }))
		end
	end
end

-- ---------------------------------------------------------------------------
-- Movimento, vazamentos, cura e chefes
-- ---------------------------------------------------------------------------

local function updateMovement(state: Types.MatchState, dt: number, events: { Types.SimEvent })
	local ids = table.clone(state.enemyOrder)
	for _, id in ipairs(ids) do
		local e = state.enemies[id]
		if e and e.alive then
			local slow = Combat.activeSlow(e, state.simTime, Balance.effects)
			if slow > 0 then
				-- tempo de lentidão atribuído ao dono da fonte mais forte
				local strongest: Types.TimedEffect? = nil
				for _, eff in ipairs(e.slows) do
					if strongest == nil or eff.strength > strongest.strength then
						strongest = eff
					end
				end
				if strongest and strongest.sourceTowerId ~= Simulation.PULSE_SOURCE_ID then
					local src = state.towers[strongest.sourceTowerId]
					if src then
						state.stats[src.ownerUserId].slowSeconds += dt
					end
				end
			end
			-- congelado (Picolé) fica parado; o chefe nunca congela, só fica lento
			local frozen = Combat.isFrozen(e, state.simTime)
			e.s += e.baseSpeed * (if frozen then 0 else 1 - slow) * dt
			if e.s >= state.pathLength then
				-- vazamento: sem divisão, sem recompensa
				cancelTelegraph(state, e, events)
				removeEnemy(state, e)
				if state.mode ~= "training" then
					local before = state.baseHP
					state.baseHP = math.max(0, state.baseHP - e.leak)
					-- o dano levado é o que decide a estrela de "sem vazamento"
					state.campaignStats.damageTaken += before - state.baseHP
				end
				table.insert(events, event(state, "leak", { entityId = e.id, enemyDefId = e.defId, amount = e.leak }))
			end
		end
	end
end

local function updateHealing(state: Types.MatchState, events: { Types.SimEvent })
	local healedThisStep: { [number]: boolean } = {}
	for _, id in ipairs(state.enemyOrder) do
		local healer = state.enemies[id]
		local def = Catalog.getEnemy(healer.defId)
		if healer.alive and def and def.healPulse and def.healInterval and def.healRadius then
			if state.simTime - healer.lastHealAt >= def.healInterval then
				healer.lastHealAt = state.simTime
				local path = getPath(state.mapId)
				local hx, hy = Path.positionAt(path, healer.s)
				local amount = def.healPulse * state.commonHpFactor
				local healed: { number } = {}
				for _, otherId in ipairs(state.enemyOrder) do
					local other = state.enemies[otherId]
					if
						other.alive
						and other.id ~= healer.id
						and not other.isBoss
						and other.defId ~= healer.defId
						and not healedThisStep[other.id]
						and other.hp < other.maxHp
						and not Combat.isHealBlocked(other, state.simTime)
					then
						local ox, oy = Path.positionAt(path, other.s)
						if Grid.distance(hx, hy, ox, oy) <= def.healRadius + 1e-9 then
							other.hp = math.min(other.maxHp, other.hp + amount)
							healedThisStep[other.id] = true
							table.insert(healed, other.id)
						end
					end
				end
				if #healed > 0 then
					table.insert(
						events,
						event(state, "heal", { entityId = healer.id, amount = amount, entityIds = healed })
					)
				end
			end
		end
	end
end

local function pickAspiradorTarget(state: Types.MatchState): Types.Tower?
	local best: Types.Tower? = nil
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		if best == nil or t.invested > best.invested or (t.invested == best.invested and t.id < best.id) then
			best = t
		end
	end
	return best
end

-- Rajada gelada: as torres que mais valem (investido), empate pelo menor id.
local function pickTopInvested(state: Types.MatchState, count: number): { number }
	local list: { Types.Tower } = {}
	for _, id in ipairs(state.towerOrder) do
		table.insert(list, state.towers[id])
	end
	table.sort(list, function(a, b)
		if a.invested ~= b.invested then
			return a.invested > b.invested
		end
		return a.id < b.id
	end)
	local out: { number } = {}
	for i = 1, math.min(count, #list) do
		table.insert(out, list[i].id)
	end
	return out
end

-- Enrolar: a torre mais perto do chefe no momento do aviso, empate pelo menor id.
local function pickNearestTower(state: Types.MatchState, boss: Types.Enemy): number?
	local bx, by = Path.positionAt(getPath(state.mapId), boss.s)
	local best: Types.Tower? = nil
	local bestD = math.huge
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		local d = Grid.distance(bx, by, t.x, t.y)
		if d < bestD - 1e-9 or (math.abs(d - bestD) <= 1e-9 and best ~= nil and t.id < best.id) then
			best = t
			bestD = d
		end
	end
	return if best then best.id else nil
end

local function summonAround(
	state: Types.MatchState,
	boss: Types.Enemy,
	def: Types.BossDef,
	events: { Types.SimEvent }
): { number }
	local count = def.summonCount or 0
	local summonType = def.summonType or "corrisco"
	local s = math.min(boss.s + 0.5, state.pathLength - 0.1)
	local summoned: { number } = {}
	for _ = 1, count do
		if #state.enemyOrder < Simulation.MAX_ENEMIES then
			local child = spawnEnemy(state, summonType, s, events, { isSummon = true, bounty = 0 })
			if child then
				table.insert(summoned, child.id)
			end
		end
	end
	return summoned
end

local function updateBosses(state: Types.MatchState, events: { Types.SimEvent })
	for _, id in ipairs(table.clone(state.enemyOrder)) do
		local boss = state.enemies[id]
		if boss and boss.alive and boss.isBoss then
			local def = Catalog.getBoss(boss.defId) :: Types.BossDef
			if not boss.bossTelegraphing and state.simTime >= boss.bossNextTelegraphAt then
				boss.bossTelegraphing = true
				boss.bossResolveAt = boss.bossNextTelegraphAt + def.telegraph
				boss.bossTargetCell = nil
				boss.bossTargetTowerIds = nil
				if def.mechanic == "dust_pulse" then
					local target = pickAspiradorTarget(state)
					if target then
						boss.bossTargetCell = { target.x, target.y }
					end
				elseif def.mechanic == "frost_blast" then
					boss.bossTargetTowerIds = pickTopInvested(state, def.targetCount or 1)
				elseif def.mechanic == "wrap" then
					local target = pickNearestTower(state, boss)
					boss.bossTargetTowerIds = if target then { target } else {}
				end
				table.insert(
					events,
					event(state, "bossTelegraph", {
						entityId = boss.id,
						enemyDefId = boss.defId,
						cell = boss.bossTargetCell,
						radius = if def.mechanic == "dust_cloud" then (def.cloudLength or 3) / 2 else def.radius,
						reason = def.mechanic,
						resolveAt = boss.bossResolveAt,
						towerIds = boss.bossTargetTowerIds,
						s = boss.s,
					})
				)
			end
			if boss.bossTelegraphing and state.simTime >= boss.bossResolveAt then
				boss.bossTelegraphing = false
				boss.bossNextTelegraphAt += def.period
				local expiresAt: number? = nil
				local dusted: { number }? = nil
				local summoned: { number }? = nil
				if def.mechanic == "dust_pulse" then
					local cell = boss.bossTargetCell
					if cell then
						local until_ = state.simTime + (def.duration or 4)
						expiresAt = until_
						dusted = {}
						for _, tid in ipairs(state.towerOrder) do
							local t = state.towers[tid]
							if Grid.distance(t.x, t.y, cell[1], cell[2]) <= (def.radius or 2) + 1e-9 then
								t.dustUntil = until_
								table.insert(dusted :: { number }, t.id)
							end
						end
					end
				elseif def.mechanic == "armor_cycle" then
					boss.bossArmorBonus = def.extraArmor or 0
					boss.bossArmorUntil = state.simTime + (def.duration or 5)
					expiresAt = boss.bossArmorUntil
				elseif def.mechanic == "summon" then
					summoned = summonAround(state, boss, def, events)
				elseif def.mechanic == "frost_blast" or def.mechanic == "wrap" then
					-- a torre marcada no aviso para de atirar e de dar aura; vendida no meio, nada acontece
					local until_ = state.simTime + (def.duration or 2)
					expiresAt = until_
					dusted = {}
					for _, tid in ipairs(boss.bossTargetTowerIds or {}) do
						local t = state.towers[tid]
						if t then
							t.disabledUntil = math.max(t.disabledUntil, until_)
							t.disabledReason = if def.mechanic == "frost_blast" then "frost" else "wrap"
							table.insert(dusted :: { number }, tid)
						end
					end
				elseif def.mechanic == "soak" then
					boss.bossSoakUntil = state.simTime + (def.duration or 3)
					expiresAt = boss.bossSoakUntil
				elseif def.mechanic == "dust_cloud" then
					local half = (def.cloudLength or 3) / 2
					local until_ = state.simTime + (def.duration or 2)
					table.insert(state.pathClouds, {
						fromS = math.max(boss.s - half, 0),
						toS = math.min(boss.s + half, state.pathLength),
						expiresAt = until_,
						bossId = boss.id,
					})
					expiresAt = until_
					summoned = summonAround(state, boss, def, events)
				end
				boss.bossTargetTowerIds = nil
				table.insert(
					events,
					event(state, "bossAbility", {
						entityId = boss.id,
						enemyDefId = boss.defId,
						cell = boss.bossTargetCell,
						radius = if def.mechanic == "dust_cloud" then (def.cloudLength or 3) / 2 else def.radius,
						reason = def.mechanic,
						expiresAt = expiresAt,
						entityIds = summoned,
						towerIds = dusted,
						s = boss.s,
					})
				)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Ataques
-- ---------------------------------------------------------------------------

-- Nuvem de pó: some quando vence. Nada além da mira usa isto (queimadura e Pulso continuam).
local function pruneClouds(state: Types.MatchState)
	local clouds = state.pathClouds
	local i = 1
	while i <= #clouds do
		if clouds[i].expiresAt <= state.simTime then
			table.remove(clouds, i)
		else
			i += 1
		end
	end
end

function Simulation.hiddenByCloud(state: Types.MatchState, s: number): boolean
	for _, cloud in ipairs(state.pathClouds) do
		if cloud.expiresAt > state.simTime and s >= cloud.fromS - 1e-9 and s <= cloud.toS + 1e-9 then
			return true
		end
	end
	return false
end

local function buildCandidates(state: Types.MatchState): { Combat.EnemyPos }
	local path = getPath(state.mapId)
	local list: { Combat.EnemyPos } = {}
	for _, id in ipairs(state.enemyOrder) do
		local e = state.enemies[id]
		if e.alive and not Simulation.hiddenByCloud(state, e.s) then
			local px, py = Path.positionAt(path, e.s)
			table.insert(list, { enemy = e, px = px, py = py })
		end
	end
	return list
end

local function towerHaste(state: Types.MatchState, tower: Types.Tower): number
	return Combat.hasteFor(tower, towerList(state), function(other: Types.Tower): number?
		if isDisabled(state, other) then
			return nil
		end
		local stats = Catalog.getStateStats(other.defId, other.state)
		return if stats then stats.haste else nil
	end, function(other: Types.Tower): number
		local stats = Catalog.getStateStats(other.defId, other.state)
		return if stats then stats.range else 0
	end)
end
Simulation.towerHaste = towerHaste

-- Aura de dano do Fofo: a maior em alcance, de torre não desligada.
local function towerBoost(state: Types.MatchState, tower: Types.Tower): number
	return Combat.boostFor(tower, towerList(state), function(other: Types.Tower): number?
		if isDisabled(state, other) then
			return nil
		end
		local stats = Catalog.getStateStats(other.defId, other.state)
		return if stats then stats.damageBoost else nil
	end, function(other: Types.Tower): number
		local stats = Catalog.getStateStats(other.defId, other.state)
		return if stats then stats.range else 0
	end)
end
Simulation.towerBoost = towerBoost

function Simulation.effectiveIntervalFor(state: Types.MatchState, tower: Types.Tower): number
	local stats = Catalog.getStateStats(tower.defId, tower.state)
	if not stats or stats.interval <= 0 then
		return 0
	end
	local haste = towerHaste(state, tower)
	local dusted = tower.dustUntil > state.simTime
	return Combat.effectiveInterval(stats.interval, haste, dusted, Simulation.DUST_FACTOR)
end

local function applyDamageToEnemy(state: Types.MatchState, enemy: Types.Enemy, amount: number, attackerUserId: number?)
	enemy.hp -= amount
	if attackerUserId then
		local st = state.stats[attackerUserId]
		if st then
			st.damage += amount
		end
	end
end

-- Parte do dano que existe por causa de uma aura (cadência ou dano) vai para o dono da aura.
local function creditSupport(state: Types.MatchState, ownerUserId: number?, amount: number, fraction: number)
	if ownerUserId and fraction > 0 then
		local st = state.stats[ownerUserId]
		if st then
			st.supportBonusDamage += amount * fraction
		end
	end
end

-- Dono da aura que deu `value` a esta torre (o primeiro na ordem das torres, como sempre foi).
local function findAuraSource(state: Types.MatchState, tower: Types.Tower, value: number, field: string): number?
	if value <= 0 then
		return nil
	end
	for _, id in ipairs(state.towerOrder) do
		local other = state.towers[id]
		if other.id ~= tower.id and not isDisabled(state, other) then
			local stats = Catalog.getStateStats(other.defId, other.state) :: any
			if
				stats
				and stats[field] == value
				and Grid.distance(tower.x, tower.y, other.x, other.y) <= stats.range + 1e-9
			then
				return other.ownerUserId
			end
		end
	end
	return nil
end

-- Picolé: congela o inimigo comum; o chefe só fica lento. Congelado não renova (sem trava eterna),
-- e depois de descongelar há um tempo de imunidade.
local function applyFreeze(
	state: Types.MatchState,
	enemy: Types.Enemy,
	tower: Types.Tower,
	stats: Types.TowerStateStats
)
	local duration = stats.freeze :: number
	if enemy.isBoss then
		Combat.applyEffect(enemy.slows, Balance.effects.frozenBossSlow, duration, tower.id, state.simTime)
		return
	end
	if Combat.isFrozen(enemy, state.simTime) or state.simTime < enemy.freezeImmuneUntil then
		return
	end
	enemy.freezeUntil = state.simTime + duration
	enemy.freezeBonus = stats.frozenBonus or 0
	enemy.freezeImmuneUntil = enemy.freezeUntil + Balance.effects.freezeImmunity
end

local function fireTower(
	state: Types.MatchState,
	tower: Types.Tower,
	def: Types.TowerDef,
	stats: Types.TowerStateStats,
	primary: Combat.EnemyPos,
	candidates: { Combat.EnemyPos },
	haste: number,
	events: { Types.SimEvent }
)
	tower.attackSeq += 1
	local now = state.simTime
	local targets: { Combat.EnemyPos }
	local falloff = 1
	if stats.allTargets then
		targets = Combat.allInRange(tower, stats.range, candidates, stats.allTargets)
	elseif stats.splash and stats.maxTargets then
		local radius = stats.splash + circuitBonusFor(tower, "splash_radius_add")
		targets = Combat.splashTargets(primary, candidates, radius, stats.maxTargets)
	elseif stats.chains and stats.chainRadius and stats.chainFalloff then
		targets = Combat.chainTargets(primary, candidates, stats.chains, stats.chainRadius)
		falloff = stats.chainFalloff + circuitBonusFor(tower, "chain_falloff_add")
		for _, c in ipairs(Balance.circuits) do
			if c.id == tower.circuitId and c.cap then
				falloff = math.min(falloff, c.cap)
			end
		end
	else
		targets = { primary }
	end
	-- Holofote: cada acerto seguido no mesmo alvo esquenta o feixe; trocar de alvo zera
	local focusBonus = 0
	if stats.focusRamp and stats.focusMax then
		if tower.focusTargetId == primary.enemy.id then
			tower.focusStacks += 1
		else
			tower.focusTargetId = primary.enemy.id
			tower.focusStacks = 0
		end
		focusBonus = math.min(tower.focusStacks * stats.focusRamp, stats.focusMax)
	end
	local boost = towerBoost(state, tower)
	local hasteOwner = findAuraSource(state, tower, haste, "haste")
	local boostOwner = findAuraSource(state, tower, boost, "damageBoost")
	local hasteFraction = if haste > 0 then haste / (1 + haste) else 0
	local boostFraction = if boost > 0 then boost / (1 + boost) else 0
	local slowedBonus = circuitBonusFor(tower, "damage_vs_slowed")
	local hitList: { Types.AttackTarget } = {}
	for k, target in ipairs(targets) do
		local enemy = target.enemy
		local enemyDef = if enemy.isBoss then nil else Catalog.getEnemy(enemy.defId)
		-- Traça: com a esquiva pronta, este acerto erra inteiro (dano e efeitos)
		if enemyDef and enemyDef.dodgeInterval and now >= enemy.dodgeReadyAt then
			enemy.dodgeReadyAt = now + enemyDef.dodgeInterval
			table.insert(hitList, { enemyId = enemy.id, damage = 0, index = k - 1, flag = 1 })
			continue
		end
		local flag = 0
		local circuitBonus = 0
		if slowedBonus > 0 and Combat.isSlowed(enemy, now) then
			circuitBonus = slowedBonus
		end
		local base = stats.damage * (falloff ^ (k - 1)) * (1 + focusBonus)
		local dmg = Combat.computeDamage({
			baseDamage = base,
			damageType = def.damageType,
			bossBonus = stats.bossBonus,
			circuitBonus = circuitBonus,
			armorIgnore = stats.armorIgnore,
			mark = Combat.activeMark(enemy, now),
			armor = Combat.currentArmor(enemy, now, Balance.effects.shredCap),
			energyResistance = enemy.energyResistance,
			isBoss = enemy.isBoss,
			armorCap = Balance.effects.physicalArmorCap,
			boost = boost,
			frozenBonus = if Combat.isFrozen(enemy, now) then enemy.freezeBonus else 0,
		})
		if enemy.isBoss and def.damageType == "energy" and enemy.bossSoakUntil > now then
			-- Esponjão encharcado: a energia não fere e vira um pouco de cura (queimadura bloqueia)
			local bossDef = Catalog.getBoss(enemy.defId)
			local heal = dmg * (if bossDef then bossDef.soakHeal or 0 else 0)
			if heal > 0 and not Combat.isHealBlocked(enemy, now) then
				enemy.hp = math.min(enemy.maxHp, enemy.hp + heal)
			end
			dmg = 0
			flag = 2
		else
			applyDamageToEnemy(state, enemy, dmg, tower.ownerUserId)
			creditSupport(state, hasteOwner, dmg, hasteFraction)
			creditSupport(state, boostOwner, dmg, boostFraction)
		end
		if stats.slow and stats.slowDuration and not (enemyDef and enemyDef.slowImmune) then
			Combat.applyEffect(enemy.slows, stats.slow, stats.slowDuration, tower.id, now)
		end
		if stats.mark and stats.markDuration then
			Combat.applyEffect(enemy.marks, stats.mark, stats.markDuration, tower.id, now)
		end
		if stats.shred and stats.shredDuration then
			Combat.applyShred(enemy.shreds, stats.shred, stats.shredDuration, tower.id, now, stats.shredStacks)
		end
		if stats.burn and stats.burnDuration then
			local dps = stats.burn * (1 + boost) * (1 + focusBonus)
			Combat.applyBurn(enemy.burns, dps, stats.burnDuration, tower.id, tower.ownerUserId, now)
		end
		if stats.freeze then
			applyFreeze(state, enemy, tower, stats)
		end
		-- empurrão: o alvo principal (ou o puxado), e todos da área no Salto Gigante
		if stats.push and (k == 1 or stats.splash ~= nil) then
			local distance = Combat.pushDistance(enemy, stats.push, now, Balance.effects)
			if distance > 0 then
				enemy.s -= distance
				enemy.pushedTotal += distance
				enemy.pushReadyAt = now + Balance.effects.pushCooldown
				flag = 3
			end
		end
		table.insert(
			hitList,
			{ enemyId = enemy.id, damage = dmg, index = k - 1, flag = if flag ~= 0 then flag else nil }
		)
	end
	-- Enxame: a chama pula para os vizinhos do alvo principal (não é acerto: não gasta esquiva)
	if stats.burnSpread and stats.burnSpreadRadius and stats.burn and stats.burnDuration then
		local dps = stats.burn * (1 + boost)
		for _, other in ipairs(Combat.spreadTargets(primary, candidates, stats.burnSpreadRadius, stats.burnSpread)) do
			Combat.applyBurn(other.enemy.burns, dps, stats.burnDuration, tower.id, tower.ownerUserId, now)
		end
	end
	if state.firstShotAt == nil then
		state.firstShotAt = now
	end
	table.insert(events, event(state, "attack", { towerId = tower.id, attackSeq = tower.attackSeq, targets = hitList }))
end

local function updateTowers(state: Types.MatchState, dt: number, events: { Types.SimEvent })
	local candidates: { Combat.EnemyPos }? = nil
	for _, id in ipairs(state.towerOrder) do
		local tower = state.towers[id]
		local def = Catalog.getTower(tower.defId)
		local stats = Catalog.getStateStats(tower.defId, tower.state)
		if def and stats then
			-- domínio: tempo colocada
			local perUser = state.activeSecondsByUserTower[tower.ownerUserId]
			if perUser then
				perUser[tower.defId] = (perUser[tower.defId] or 0) + dt
			end
			if isDisabled(state, tower) then
				-- desligada por chefe (Boneco de Poeira, Meia): não atira, não recarrega, não dá aura
				continue
			elseif def.damageType == "none" then
				-- apoio: pulso cosmético no máximo uma vez por segundo, se há alguma torre de dano em alcance
				local last = state.lastSupportPulseAt[id] or -math.huge
				if state.simTime - last >= 1 then
					for _, otherId in ipairs(state.towerOrder) do
						local other = state.towers[otherId]
						local otherDef = Catalog.getTower(other.defId)
						if
							otherDef
							and otherDef.damageType ~= "none"
							and Grid.distance(tower.x, tower.y, other.x, other.y) <= stats.range + 1e-9
						then
							state.lastSupportPulseAt[id] = state.simTime
							tower.attackSeq += 1
							table.insert(events, event(state, "support", { towerId = id, attackSeq = tower.attackSeq }))
							break
						end
					end
				end
			else
				tower.cooldown = math.max(0, tower.cooldown - dt)
				if tower.cooldown <= 0 then
					if candidates == nil then
						candidates = buildCandidates(state)
					end
					local mode: Types.TargetMode = tower.targetMode
					local list = candidates :: { Combat.EnemyPos }
					-- Língua de Sogra puxa o inimigo comum mais forte; sem nenhum, ataca como as outras
					local primary = if stats.grab then Combat.selectGrabTarget(tower, stats.range, list) else nil
					if primary == nil then
						primary = Combat.selectTarget(tower, stats.range, list, mode)
					end
					if primary then
						local haste = towerHaste(state, tower)
						local dusted = tower.dustUntil > state.simTime
						local interval = Combat.effectiveInterval(stats.interval, haste, dusted, Simulation.DUST_FACTOR)
						fireTower(state, tower, def, stats, primary, candidates :: { Combat.EnemyPos }, haste, events)
						tower.cooldown = interval
					end
				end
			end
		end
	end
end

-- Queimadura: dano de energia contínuo, creditado ao dono de quem acendeu. Esponjão encharcado
-- absorve (sem dano), mas continua sem cura enquanto queima.
local function updateBurns(state: Types.MatchState, dt: number)
	local now = state.simTime
	for _, id in ipairs(state.enemyOrder) do
		local e = state.enemies[id]
		if e.alive and #e.burns > 0 then
			local burn = Combat.activeBurn(e, now)
			if burn and not (e.isBoss and e.bossSoakUntil > now) then
				local dmg = Combat.computeDamage({
					baseDamage = burn.strength * dt,
					damageType = "energy",
					mark = Combat.activeMark(e, now),
					armor = 0,
					energyResistance = e.energyResistance,
					isBoss = e.isBoss,
					armorCap = Balance.effects.physicalArmorCap,
					frozenBonus = if Combat.isFrozen(e, now) then e.freezeBonus else 0,
				})
				applyDamageToEnemy(state, e, dmg, burn.ownerUserId)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Mortes e pagamentos
-- ---------------------------------------------------------------------------

local function processDeaths(state: Types.MatchState, events: { Types.SimEvent })
	local ids = table.clone(state.enemyOrder)
	for _, id in ipairs(ids) do
		local e = state.enemies[id]
		if e and e.alive and e.hp <= 0 then
			cancelTelegraph(state, e, events)
			removeEnemy(state, e)
			local paid = 0
			if not e.isSummon and e.bounty > 0 then
				local split = Rewards.splitBounty(e.bounty, state.participantOrder, state.bountyCursor)
				state.bountyCursor = split.cursor
				for userId, share in pairs(split.shares) do
					state.wallets[userId] += share
					paid += share
				end
			end
			table.insert(
				events,
				event(state, "death", { entityId = e.id, enemyDefId = e.defId, amount = paid, s = e.s })
			)
			local def = Catalog.getEnemy(e.defId)
			if def and def.splitOnDeath and def.splitOnDeath > 0 then
				local childHp = math.ceil(Simulation.CASULO_CHILD_HP * state.commonHpFactor)
				for _ = 1, def.splitOnDeath do
					if #state.enemyOrder < Simulation.MAX_ENEMIES then
						spawnEnemy(state, "fiapo", e.s, events, {
							hp = childHp,
							speed = Simulation.CASULO_CHILD_SPEED,
							leak = Simulation.CASULO_CHILD_LEAK,
							bounty = 0,
							isSummon = true,
						})
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Passo
-- ---------------------------------------------------------------------------

function Simulation.step(state: Types.MatchState, dtOverride: number?): { Types.SimEvent }
	local events: { Types.SimEvent } = {}
	-- na decisão da Retomada o tempo de simulação para: nada nasce, nada anda
	if Simulation.isTerminal(state) or state.phase == "RetryDecision" then
		return events
	end
	local dt = dtOverride or Simulation.STEP
	state.simTime += dt
	state.revision += 1

	-- Com início manual (primeira fase), preparação e intervalo só acabam quando o jogador
	-- chama a onda: não há cronômetro correndo.
	local timerElapsed = not state.manualWaveStart and state.simTime >= state.phaseEndsAt
	if state.phase == "Preparation" then
		if timerElapsed or allActiveReady(state) then
			startWave(state, 1, events)
		else
			return events
		end
	elseif state.phase == "Intermission" then
		if #state.enemyOrder == 0 and (timerElapsed or allActiveReady(state)) then
			startWave(state, state.waveIndex + 1, events)
		end
	end

	updateSpawning(state, events)
	updateMovement(state, dt, events)
	if state.baseHP <= 0 and state.mode ~= "training" then
		onBaseDestroyed(state, events)
		return events
	end
	pruneClouds(state)
	updateHealing(state, events)
	updateBosses(state, events)
	updateBurns(state, dt)
	updateTowers(state, dt, events)
	processDeaths(state, events)

	if state.phase == "Wave" and state.mode ~= "training" then
		local rt = state.waveRuntime
		local bossPending = rt.bossScheduledAt ~= nil and not rt.bossSpawned
		if rt.allGroupsSpawned and not bossPending and #state.enemyOrder == 0 then
			completeWave(state, events)
		end
	end
	return events
end

-- ---------------------------------------------------------------------------
-- Comandos (o servidor já validou sessão, forma do payload e limites de taxa)
-- ---------------------------------------------------------------------------

local function fail(state: Types.MatchState, code: string, userId: number?): Types.CommandResult
	return {
		ok = false,
		errorCode = code,
		balance = if userId then state.wallets[userId] else nil,
		revision = state.revision,
	}
end

local function success(state: Types.MatchState, userId: number?, entityId: number?): Types.CommandResult
	return {
		ok = true,
		balance = if userId then state.wallets[userId] else nil,
		revision = state.revision,
		entityId = entityId,
	}
end

local function bump(state: Types.MatchState, userId: number)
	state.revision += 1
	local st = state.stats[userId]
	if st then
		st.commandsIssued += 1
	end
end

-- `free`: a torre sai de graça pelo Reforço (quem confere a ficha é o servidor, antes de chamar).
export type PlaceOptions = { unlockedTowerIds: { string }?, free: boolean? }

function Simulation.canPlaceAt(state: Types.MatchState, x: number, y: number): (boolean, string?)
	if not Grid.inBounds(x, y) then
		return false, "INVALID_CELL"
	end
	if Path.isPathCell(getPath(state.mapId), x, y) then
		return false, "INVALID_CELL"
	end
	if getBlocked(state.mapId)[Grid.cellKey(x, y)] then
		return false, "INVALID_CELL"
	end
	if state.cellOccupancy[Grid.cellKey(x, y)] then
		return false, "OCCUPIED"
	end
	return true, nil
end

function Simulation.placeTower(
	state: Types.MatchState,
	userId: number,
	towerId: string,
	x: number,
	y: number,
	options: PlaceOptions?
): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if not Simulation.isCombatPhase(state) then
		return fail(state, "INVALID_STATE", userId), events
	end
	local participant = Simulation.getParticipant(state, userId)
	if not participant then
		return fail(state, "NOT_OWNER"), events
	end
	local def = Catalog.getTower(towerId)
	if not def then
		return fail(state, "INVALID_STATE", userId), events
	end
	if not state.trainingUnlockAll then
		if table.find(participant.loadout, towerId) == nil then
			return fail(state, "INVALID_STATE", userId), events
		end
		local unlocked = if options then options.unlockedTowerIds else nil
		if unlocked and table.find(unlocked, towerId) == nil then
			return fail(state, "INVALID_STATE", userId), events
		end
	end
	local okCell, cellError = Simulation.canPlaceAt(state, x, y)
	if not okCell then
		return fail(state, cellError :: string, userId), events
	end
	if Simulation.countTowersOwned(state, userId, nil) >= Simulation.towerLimitPerPlayer(state) then
		return fail(state, "LIMIT_REACHED", userId), events
	end
	if Simulation.countTowersOwned(state, userId, towerId) >= def.perPlayerLimit then
		return fail(state, "LIMIT_REACHED", userId), events
	end
	local free = options ~= nil and options.free == true
	if free and not Simulation.canUseSupport(state, userId) then
		return fail(state, "INVALID_STATE", userId), events
	end
	-- torre do Reforço não custa nada e não entra no investido: vender devolve só as melhorias
	local cost = if free then 0 else def.states.L0.cost
	if state.mode ~= "training" and not free then
		if state.wallets[userId] < cost then
			return fail(state, "INSUFFICIENT_FUNDS", userId), events
		end
		state.wallets[userId] -= cost
	end
	local id = state.nextEntityId
	state.nextEntityId += 1
	local tower: Types.Tower = {
		id = id,
		ownerUserId = userId,
		defId = towerId,
		state = "L0",
		x = x,
		y = y,
		cooldown = 0,
		targetMode = if def.target == "strongest" then "strongest" else "first",
		invested = cost,
		placedAt = state.simTime,
		circuitPartnerId = nil,
		circuitId = nil,
		dustUntil = 0,
		attackSeq = 0,
		activeSeconds = 0,
		disabledUntil = 0,
		disabledReason = nil,
		focusTargetId = nil,
		focusStacks = 0,
	}
	state.towers[id] = tower
	table.insert(state.towerOrder, id)
	state.cellOccupancy[Grid.cellKey(x, y)] = id
	state.stats[userId].towersPlaced += 1
	if free then
		state.supportUsedBy[userId] = true
		state.assisted = true
	end
	-- objetivos de fase olham quantas torres foram construídas e quais tipos entraram em campo
	state.campaignStats.towersBuilt += 1
	state.campaignStats.towerIds[towerId] = true
	bump(state, userId)
	table.insert(events, event(state, "towerPlaced", { towerId = id, userId = userId, cell = { x, y }, amount = cost }))
	recomputeCircuits(state, events)
	return success(state, userId, id), events
end

function Simulation.upgradeTower(
	state: Types.MatchState,
	userId: number,
	entityId: number,
	nextState: string
): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if not Simulation.isCombatPhase(state) then
		return fail(state, "INVALID_STATE", userId), events
	end
	local tower = state.towers[entityId]
	if not tower then
		return fail(state, "INVALID_STATE", userId), events
	end
	if tower.ownerUserId ~= userId then
		return fail(state, "NOT_OWNER", userId), events
	end
	if not Catalog.canTransition(tower.state, nextState) then
		return fail(state, "INVALID_STATE", userId), events
	end
	local oldStats = Catalog.getStateStats(tower.defId, tower.state) :: Types.TowerStateStats
	local newStats = Catalog.getStateStats(tower.defId, nextState)
	if not newStats then
		return fail(state, "INVALID_STATE", userId), events
	end
	if state.mode ~= "training" then
		if state.wallets[userId] < newStats.cost then
			return fail(state, "INSUFFICIENT_FUNDS", userId), events
		end
		state.wallets[userId] -= newStats.cost
	end
	tower.cooldown = Combat.carryCooldown(tower.cooldown, oldStats.interval, newStats.interval)
	tower.state = nextState :: Types.TowerStateId
	tower.invested += newStats.cost
	bump(state, userId)
	table.insert(
		events,
		event(
			state,
			"towerUpgraded",
			{ towerId = entityId, userId = userId, reason = nextState, amount = newStats.cost }
		)
	)
	return success(state, userId, entityId), events
end

function Simulation.sellTower(
	state: Types.MatchState,
	userId: number,
	entityId: number
): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if not Simulation.isCombatPhase(state) then
		return fail(state, "INVALID_STATE", userId), events
	end
	local tower = state.towers[entityId]
	if not tower then
		return fail(state, "INVALID_STATE", userId), events
	end
	if tower.ownerUserId ~= userId then
		return fail(state, "NOT_OWNER", userId), events
	end
	local refund = Rewards.sellRefund(tower.invested, Balance.sellRefund)
	if state.mode ~= "training" then
		state.wallets[userId] += refund
	end
	state.towers[entityId] = nil
	TableUtil.removeValue(state.towerOrder, entityId)
	state.cellOccupancy[Grid.cellKey(tower.x, tower.y)] = nil
	state.lastSupportPulseAt[entityId] = nil
	state.campaignStats.towersSold += 1
	bump(state, userId)
	table.insert(events, event(state, "towerSold", { towerId = entityId, userId = userId, amount = refund }))
	recomputeCircuits(state, events)
	return success(state, userId, entityId), events
end

function Simulation.setTarget(
	state: Types.MatchState,
	userId: number,
	entityId: number,
	mode: string
): Types.CommandResult
	if not Simulation.isCombatPhase(state) then
		return fail(state, "INVALID_STATE", userId)
	end
	local tower = state.towers[entityId]
	if not tower then
		return fail(state, "INVALID_STATE", userId)
	end
	if tower.ownerUserId ~= userId then
		return fail(state, "NOT_OWNER", userId)
	end
	local def = Catalog.getTower(tower.defId)
	if not def or def.damageType == "none" then
		return fail(state, "INVALID_STATE", userId)
	end
	if table.find(Catalog.TARGET_MODES, mode :: any) == nil then
		return fail(state, "INVALID_STATE", userId)
	end
	tower.targetMode = mode :: Types.TargetMode
	bump(state, userId)
	return success(state, userId, entityId)
end

function Simulation.castPulse(state: Types.MatchState, userId: number): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if state.phase ~= "Wave" then
		return fail(state, "INVALID_STATE", userId), events
	end
	local participant = Simulation.getParticipant(state, userId)
	if not participant or not participant.active then
		return fail(state, "NOT_OWNER", userId), events
	end
	if state.simTime < state.pulseReadyAt then
		return fail(state, "INVALID_STATE", userId), events
	end
	local pulse = Balance.pulse
	-- disponibilidade, consumo e efeito são atômicos neste passo
	state.pulseReadyAt = state.simTime + pulse.cooldown
	local damage = pulse.damage * (if pulse.scaleDamageWithCoop then state.coopFactor else 1)
	local hits: { Types.AttackTarget } = {}
	for _, id in ipairs(state.enemyOrder) do
		local enemy = state.enemies[id]
		if enemy.alive then
			local dmg = Combat.computeDamage({
				baseDamage = damage,
				damageType = pulse.damageType,
				bossBonus = 0,
				circuitBonus = 0,
				armorIgnore = 0,
				mark = Combat.activeMark(enemy, state.simTime),
				armor = Combat.currentArmor(enemy, state.simTime),
				energyResistance = enemy.energyResistance,
				isBoss = enemy.isBoss,
				armorCap = Balance.effects.physicalArmorCap,
			})
			applyDamageToEnemy(state, enemy, dmg, userId)
			Combat.applyEffect(enemy.slows, pulse.slow, pulse.slowDuration, Simulation.PULSE_SOURCE_ID, state.simTime)
			table.insert(hits, { enemyId = enemy.id, damage = dmg, index = 0 })
		end
	end
	bump(state, userId)
	table.insert(events, event(state, "pulse", { userId = userId, targets = hits, amount = damage }))
	return success(state, userId), events
end

function Simulation.setReady(state: Types.MatchState, userId: number, ready: boolean): Types.CommandResult
	if state.phase ~= "Preparation" and state.phase ~= "Intermission" then
		return fail(state, "INVALID_STATE", userId)
	end
	local participant = Simulation.getParticipant(state, userId)
	if not participant then
		return fail(state, "NOT_OWNER", userId)
	end
	participant.ready = ready
	bump(state, userId)
	return success(state, userId)
end

function Simulation.recomputeSpeed(state: Types.MatchState): boolean
	local target = 2
	if state.manualWaveStart then
		target = 1 -- a primeira fase é o passo a passo: velocidade dobrada atrapalha
	else
		local anyActive = false
		for _, p in ipairs(state.participants) do
			if p.active then
				anyActive = true
				if p.speedVote ~= 2 then
					target = 1
				end
			end
		end
		if not anyActive then
			target = 1
		end
	end
	if target ~= state.speedMultiplier then
		state.speedMultiplier = target
		return true
	end
	return false
end

function Simulation.voteSpeed(
	state: Types.MatchState,
	userId: number,
	value: number
): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if Simulation.isTerminal(state) then
		return fail(state, "INVALID_STATE", userId), events
	end
	if value ~= 1 and value ~= 2 then
		return fail(state, "INVALID_STATE", userId), events
	end
	if state.manualWaveStart and value == 2 then
		return fail(state, "INVALID_STATE", userId), events
	end
	local participant = Simulation.getParticipant(state, userId)
	if not participant then
		return fail(state, "NOT_OWNER", userId), events
	end
	participant.speedVote = value
	bump(state, userId)
	if Simulation.recomputeSpeed(state) then
		table.insert(events, event(state, "speedChanged", { speed = state.speedMultiplier }))
	end
	return success(state, userId), events
end

-- Forçar 1x por sobrecarga do servidor (aviso)
function Simulation.forceSpeed(state: Types.MatchState, value: number, events: { Types.SimEvent })
	for _, p in ipairs(state.participants) do
		p.speedVote = math.min(p.speedVote, value)
	end
	if Simulation.recomputeSpeed(state) then
		table.insert(events, event(state, "speedChanged", { speed = state.speedMultiplier, reason = "overload" }))
	end
end

-- Presença: o servidor chama ao desconectar/retornar e após 30 s ausente.
function Simulation.setParticipantPresence(
	state: Types.MatchState,
	userId: number,
	connected: boolean,
	active: boolean
): { Types.SimEvent }
	local events: { Types.SimEvent } = {}
	local participant = Simulation.getParticipant(state, userId)
	if not participant then
		return events
	end
	participant.connected = connected
	participant.active = active
	if not active then
		participant.ready = false
	end
	state.revision += 1
	if Simulation.recomputeSpeed(state) then
		table.insert(events, event(state, "speedChanged", { speed = state.speedMultiplier }))
	end
	table.insert(
		events,
		event(state, "presence", { userId = userId, reason = if connected then "connected" else "disconnected" })
	)
	return events
end

function Simulation.abandon(state: Types.MatchState): { Types.SimEvent }
	local events: { Types.SimEvent } = {}
	if Simulation.isTerminal(state) then
		return events
	end
	state.phase = "Abandoned"
	state.result = {
		outcome = "abandoned",
		wavesCompleted = math.max(state.waveIndex - 1, 0),
		buttonsPerPlayer = 0,
		xpPerPlayer = 0,
		assisted = state.assisted,
		eligibleUserIds = {},
		levelId = state.levelId,
		stars = 0,
		starsEarned = {},
		campaignStats = state.campaignStats,
		masteryByUser = {},
		statsByUser = state.stats,
		durationSim = state.simTime,
	}
	state.revision += 1
	table.insert(events, event(state, "matchEnd", { phase = "Abandoned" }))
	return events
end

-- ---------------------------------------------------------------------------
-- Retomada
-- ---------------------------------------------------------------------------

-- Volta a partida para o início da onda perdida: torres, carteiras, recarga do Pulso e as
-- estatísticas de estrela voltam à foto; o Farol volta cheio e há uma preparação curta.
-- O relógio de simulação, a revisão e os ids de entidade **não** voltam: o cliente precisa deles
-- sempre crescendo. Quem confere e consome a ficha é o servidor, antes de chamar isto.
function Simulation.applyRetry(state: Types.MatchState): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if not Simulation.canRetry(state) then
		return fail(state, "INVALID_STATE"), events
	end
	local checkpoint = state.checkpoint :: Types.Checkpoint
	clearEnemies(state, events)
	state.wallets = table.clone(checkpoint.wallets)
	state.towers = TableUtil.deepClone(checkpoint.towers)
	state.towerOrder = table.clone(checkpoint.towerOrder)
	state.cellOccupancy = table.clone(checkpoint.cellOccupancy)
	state.bountyCursor = checkpoint.bountyCursor
	state.campaignStats = TableUtil.deepClone(checkpoint.campaignStats)
	state.pulseReadyAt = state.simTime + checkpoint.pulseRemaining
	state.lastSupportPulseAt = {}
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		t.cooldown = 0
		t.dustUntil = 0
		t.disabledUntil = 0
		t.disabledReason = nil
		t.focusTargetId = nil
		t.focusStacks = 0
	end
	state.pathClouds = {}
	state.baseHP = Balance.baseHP
	state.retryUsed = true
	state.assisted = true
	state.lostAtWave = 0
	state.waveIndex = checkpoint.waveIndex - 1
	state.phase = "Intermission"
	state.phaseEndsAt = if state.manualWaveStart then math.huge else state.simTime + Balance.shop.retry.prepSeconds
	state.waveRuntime = {
		groupIndex = 0,
		spawnedInGroup = 0,
		nextSpawnAt = state.simTime,
		allGroupsSpawned = true,
		bossScheduledAt = nil,
		bossSpawned = false,
		waveStartedAt = state.simTime,
	}
	resetReady(state)
	state.revision += 1
	table.insert(events, event(state, "retryApplied", { wave = checkpoint.waveIndex, phase = "Intermission" }))
	return success(state), events
end

-- Ninguém quis (ou o prazo acabou): a derrota vira definitiva pelo caminho de sempre.
function Simulation.declineRetry(state: Types.MatchState): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if state.phase ~= "RetryDecision" then
		return fail(state, "INVALID_STATE"), events
	end
	finishMatch(state, "lost", events)
	state.revision += 1
	return success(state), events
end

-- ---------------------------------------------------------------------------
-- Ferramenta de desenvolvimento: saltar para uma onda (somente via DevCommand autorizado)
-- ---------------------------------------------------------------------------

function Simulation.devJumpToWave(
	state: Types.MatchState,
	targetWave: number
): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if state.mode ~= "normal" or Simulation.isTerminal(state) then
		return fail(state, "INVALID_STATE"), events
	end
	local target = math.clamp(math.floor(targetWave), 1, state.totalWaves)
	for _, id in ipairs(table.clone(state.enemyOrder)) do
		removeEnemy(state, state.enemies[id])
		table.insert(events, event(state, "despawn", { entityId = id }))
	end
	state.trainingQueue = {}
	state.pathClouds = {}
	state.waveIndex = target - 1
	state.phase = "Intermission"
	state.phaseEndsAt = state.simTime
	state.waveRuntime.allGroupsSpawned = true
	state.waveRuntime.bossScheduledAt = nil
	state.waveRuntime.bossSpawned = false
	resetReady(state)
	state.revision += 1
	table.insert(events, event(state, "phase", { phase = "Intermission", wave = target }))
	return success(state), events
end

-- Encerra a partida na hora, do jeito que o fim normal encerra: quem decide recompensa,
-- persistência e tela de resultado continua sendo o laço do MatchService, que só olha para
-- `state.result`. As estrelas podem ser forçadas porque é isso que se quer testar — sem isso,
-- conferir a fase 12 com três estrelas exigiria jogar a fase 12 com três estrelas.
function Simulation.devFinish(
	state: Types.MatchState,
	outcome: "won" | "lost",
	stars: number?
): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if Simulation.isTerminal(state) then
		return fail(state, "INVALID_STATE"), events
	end
	finishMatch(state, outcome, events)
	local result = state.result
	if result and stars ~= nil then
		local target = math.clamp(math.floor(stars), 0, 3)
		result.stars = target
		result.starsEarned = { target >= 1, target >= 2, target >= 3 }
	end
	state.revision += 1
	return success(state), events
end

-- ---------------------------------------------------------------------------
-- Treino
-- ---------------------------------------------------------------------------

function Simulation.trainingSpawn(state: Types.MatchState, enemyId: string, count: number): Types.CommandResult
	if state.mode ~= "training" then
		return fail(state, "INVALID_STATE")
	end
	if not Catalog.getEnemy(enemyId) and not Catalog.getBoss(enemyId) then
		return fail(state, "INVALID_STATE")
	end
	local n = math.clamp(math.floor(count), 1, 10)
	for i = 1, n do
		table.insert(state.trainingQueue, { defId = enemyId, at = state.simTime + (i - 1) * 0.6 })
	end
	state.revision += 1
	return success(state)
end

function Simulation.trainingClear(state: Types.MatchState): (Types.CommandResult, { Types.SimEvent })
	local events: { Types.SimEvent } = {}
	if state.mode ~= "training" then
		return fail(state, "INVALID_STATE"), events
	end
	state.trainingQueue = {}
	for _, id in ipairs(table.clone(state.enemyOrder)) do
		local e = state.enemies[id]
		removeEnemy(state, e)
		table.insert(events, event(state, "despawn", { entityId = id }))
	end
	for _, id in ipairs(table.clone(state.towerOrder)) do
		local t = state.towers[id]
		state.towers[id] = nil
		state.cellOccupancy[Grid.cellKey(t.x, t.y)] = nil
		table.insert(events, event(state, "towerSold", { towerId = id, userId = t.ownerUserId, amount = 0 }))
	end
	state.towerOrder = {}
	state.baseHP = Balance.baseHP
	state.revision += 1
	return success(state), events
end

return Simulation
