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
		bossHpFactor = difficulty.hp * coop * (config.hpScale or 1),
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
		},
		lastSupportPulseAt = {},
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

-- A fase usa as N primeiras ondas da tabela global; passar do fim da fase é fim de partida.
function Simulation.getWaveDef(state: Types.MatchState, index: number): Types.WaveDef?
	if index > state.totalWaves then
		return nil
	end
	return Balance.waves[index]
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

local function startWave(state: Types.MatchState, index: number, events: { Types.SimEvent })
	grantEarlyWaveBonus(state, index, events)
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

local function finishMatch(state: Types.MatchState, outcome: "won" | "lost", events: { Types.SimEvent })
	local difficulty = Catalog.getDifficulty(state.difficulty) :: Types.DifficultyDef
	local wavesCompleted = if outcome == "won" then state.totalWaves else math.max(state.waveIndex - 1, 0)
	local buttons = Rewards.buttonsForOutcome(state.mode, outcome, wavesCompleted, difficulty, Balance.rewards)
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
		then Stars.evaluate(level, outcome == "won", state.campaignStats)
		else { stars = 0, earned = {} }
	state.result = {
		outcome = outcome,
		wavesCompleted = wavesCompleted,
		buttonsPerPlayer = buttons,
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

local function completeWave(state: Types.MatchState, events: { Types.SimEvent })
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
				if waveDef.bossAfterGroups then
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
			e.s += e.baseSpeed * (1 - slow) * dt
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

local function updateBosses(state: Types.MatchState, events: { Types.SimEvent })
	for _, id in ipairs(table.clone(state.enemyOrder)) do
		local boss = state.enemies[id]
		if boss and boss.alive and boss.isBoss then
			local def = Catalog.getBoss(boss.defId) :: Types.BossDef
			if not boss.bossTelegraphing and state.simTime >= boss.bossNextTelegraphAt then
				boss.bossTelegraphing = true
				boss.bossResolveAt = boss.bossNextTelegraphAt + def.telegraph
				boss.bossTargetCell = nil
				if def.mechanic == "dust_pulse" then
					local target = pickAspiradorTarget(state)
					if target then
						boss.bossTargetCell = { target.x, target.y }
					end
				end
				table.insert(
					events,
					event(state, "bossTelegraph", {
						entityId = boss.id,
						enemyDefId = boss.defId,
						cell = boss.bossTargetCell,
						radius = def.radius,
						reason = def.mechanic,
						resolveAt = boss.bossResolveAt,
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
					local count = def.summonCount or 0
					local summonType = def.summonType or "corrisco"
					local s = math.min(boss.s + 0.5, state.pathLength - 0.1)
					summoned = {}
					for _ = 1, count do
						if #state.enemyOrder < Simulation.MAX_ENEMIES then
							local child = spawnEnemy(state, summonType, s, events, { isSummon = true, bounty = 0 })
							if child then
								table.insert(summoned :: { number }, child.id)
							end
						end
					end
				end
				table.insert(
					events,
					event(state, "bossAbility", {
						entityId = boss.id,
						enemyDefId = boss.defId,
						cell = boss.bossTargetCell,
						radius = def.radius,
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

local function buildCandidates(state: Types.MatchState): { Combat.EnemyPos }
	local path = getPath(state.mapId)
	local list: { Combat.EnemyPos } = {}
	for _, id in ipairs(state.enemyOrder) do
		local e = state.enemies[id]
		if e.alive then
			local px, py = Path.positionAt(path, e.s)
			table.insert(list, { enemy = e, px = px, py = py })
		end
	end
	return list
end

local function towerHaste(state: Types.MatchState, tower: Types.Tower): number
	return Combat.hasteFor(tower, towerList(state), function(other: Types.Tower): number?
		local stats = Catalog.getStateStats(other.defId, other.state)
		return if stats then stats.haste else nil
	end, function(other: Types.Tower): number
		local stats = Catalog.getStateStats(other.defId, other.state)
		return if stats then stats.range else 0
	end)
end
Simulation.towerHaste = towerHaste

function Simulation.effectiveIntervalFor(state: Types.MatchState, tower: Types.Tower): number
	local stats = Catalog.getStateStats(tower.defId, tower.state)
	if not stats or stats.interval <= 0 then
		return 0
	end
	local haste = towerHaste(state, tower)
	local dusted = tower.dustUntil > state.simTime
	return Combat.effectiveInterval(stats.interval, haste, dusted, Simulation.DUST_FACTOR)
end

local function applyDamageToEnemy(
	state: Types.MatchState,
	enemy: Types.Enemy,
	amount: number,
	attackerUserId: number?,
	supportOwnerUserId: number?,
	supportFraction: number
)
	enemy.hp -= amount
	if attackerUserId then
		local st = state.stats[attackerUserId]
		if st then
			st.damage += amount
		end
	end
	if supportOwnerUserId and supportFraction > 0 then
		local st = state.stats[supportOwnerUserId]
		if st then
			st.supportBonusDamage += amount * supportFraction
		end
	end
end

local function findHasteSource(state: Types.MatchState, tower: Types.Tower, haste: number): number?
	if haste <= 0 then
		return nil
	end
	for _, id in ipairs(state.towerOrder) do
		local other = state.towers[id]
		if other.defId == "maestro" then
			local stats = Catalog.getStateStats(other.defId, other.state)
			if
				stats
				and stats.haste == haste
				and Grid.distance(tower.x, tower.y, other.x, other.y) <= stats.range + 1e-9
			then
				return other.ownerUserId
			end
		end
	end
	return nil
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
	local targets: { Combat.EnemyPos }
	local falloff = 1
	if stats.splash and stats.maxTargets then
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
	local supportOwner = findHasteSource(state, tower, haste)
	local supportFraction = if haste > 0 then haste / (1 + haste) else 0
	local slowedBonus = circuitBonusFor(tower, "damage_vs_slowed")
	local hitList: { Types.AttackTarget } = {}
	for k, target in ipairs(targets) do
		local enemy = target.enemy
		local circuitBonus = 0
		if slowedBonus > 0 and Combat.isSlowed(enemy, state.simTime) then
			circuitBonus = slowedBonus
		end
		local base = stats.damage * (falloff ^ (k - 1))
		local dmg = Combat.computeDamage({
			baseDamage = base,
			damageType = def.damageType,
			bossBonus = stats.bossBonus,
			circuitBonus = circuitBonus,
			armorIgnore = stats.armorIgnore,
			mark = Combat.activeMark(enemy, state.simTime),
			armor = Combat.currentArmor(enemy, state.simTime),
			energyResistance = enemy.energyResistance,
			isBoss = enemy.isBoss,
			armorCap = Balance.effects.physicalArmorCap,
		})
		applyDamageToEnemy(state, enemy, dmg, tower.ownerUserId, supportOwner, supportFraction)
		if stats.slow and stats.slowDuration then
			Combat.applyEffect(enemy.slows, stats.slow, stats.slowDuration, tower.id, state.simTime)
		end
		if stats.mark and stats.markDuration then
			Combat.applyEffect(enemy.marks, stats.mark, stats.markDuration, tower.id, state.simTime)
		end
		table.insert(hitList, { enemyId = enemy.id, damage = dmg, index = k - 1 })
	end
	if state.firstShotAt == nil then
		state.firstShotAt = state.simTime
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
			if def.damageType == "none" then
				-- apoio: pulso cosmético no máximo uma vez por segundo, se há alguma torre de dano em alcance
				local last = state.lastSupportPulseAt[id] or -math.huge
				if state.simTime - last >= 1 then
					for _, otherId in ipairs(state.towerOrder) do
						local other = state.towers[otherId]
						if
							other.defId ~= "maestro"
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
					local primary = Combat.selectTarget(tower, stats.range, candidates :: { Combat.EnemyPos }, mode)
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
	if Simulation.isTerminal(state) then
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
		finishMatch(state, "lost", events)
		return events
	end
	updateHealing(state, events)
	updateBosses(state, events)
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

export type PlaceOptions = { unlockedTowerIds: { string }? }

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
	local cost = def.states.L0.cost
	if state.mode ~= "training" then
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
	}
	state.towers[id] = tower
	table.insert(state.towerOrder, id)
	state.cellOccupancy[Grid.cellKey(x, y)] = id
	state.stats[userId].towersPlaced += 1
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
			applyDamageToEnemy(state, enemy, dmg, userId, nil, 0)
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
