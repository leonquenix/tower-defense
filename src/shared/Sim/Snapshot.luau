--!strict
-- Constrói snapshots de replicação a partir do estado da simulação. Só dados da partida do destinatário.
local Types = require(script.Parent.Parent.Types)
local Balance = require(script.Parent.Parent.Config.Balance)
local Combat = require(script.Parent.Parent.Rules.Combat)
local Simulation = require(script.Parent.Simulation)

local Snapshot = {}

-- Estados visíveis do inimigo num byte (o cliente desenha queimadura, gelo, raspagem, esponja
-- encharcada e nuvem a partir disto). Só apresentação: quem decide tudo é a simulação.
Snapshot.FX = table.freeze({
	burning = 1,
	frozen = 2,
	shredded = 4,
	soaking = 8,
	hidden = 16,
})

function Snapshot.enemyFx(state: Types.MatchState, e: Types.Enemy): number
	local now = state.simTime
	local fx = 0
	if #e.burns > 0 and Combat.activeBurn(e, now) then
		fx += Snapshot.FX.burning
	end
	if Combat.isFrozen(e, now) then
		fx += Snapshot.FX.frozen
	end
	if #e.shreds > 0 and Combat.activeShred(e, now, Balance.effects.shredCap) > 0 then
		fx += Snapshot.FX.shredded
	end
	if e.isBoss and e.bossSoakUntil > now then
		fx += Snapshot.FX.soaking
	end
	if Simulation.hiddenByCloud(state, e.s) then
		fx += Snapshot.FX.hidden
	end
	return fx
end

local function participantColor(state: Types.MatchState, userId: number): number
	for i, id in ipairs(state.participantOrder) do
		if id == userId then
			return i
		end
	end
	return 1
end

function Snapshot.enemies(state: Types.MatchState): { Types.EnemySnapshot }
	local list: { Types.EnemySnapshot } = {}
	for _, id in ipairs(state.enemyOrder) do
		local e = state.enemies[id]
		if e.alive then
			local slow = Combat.activeSlow(e, state.simTime, Balance.effects)
			local armorBonus = if e.isBoss and e.bossArmorUntil > state.simTime then e.bossArmorBonus else 0
			table.insert(list, {
				id = e.id,
				d = e.defId,
				b = e.isBoss,
				hp = e.hp,
				mhp = e.maxHp,
				s = e.s,
				v = if Combat.isFrozen(e, state.simTime) then 0 else e.baseSpeed * (1 - slow),
				sl = slow,
				mk = Combat.activeMark(e, state.simTime),
				sm = e.isSummon,
				tg = e.bossTelegraphing,
				-- prazo real do aviso: o cliente reconstrói a contagem mesmo após atraso de rede
				tga = if e.bossTelegraphing then e.bossResolveAt else nil,
				ab = armorBonus,
				ar = Combat.currentArmor(e, state.simTime, Balance.effects.shredCap),
				er = e.energyResistance,
				fx = Snapshot.enemyFx(state, e),
			})
		end
	end
	return list
end

function Snapshot.towers(state: Types.MatchState): { Types.TowerSnapshot }
	local list: { Types.TowerSnapshot } = {}
	for _, id in ipairs(state.towerOrder) do
		local t = state.towers[id]
		table.insert(list, {
			id = t.id,
			o = t.ownerUserId,
			d = t.defId,
			st = t.state :: string,
			x = t.x,
			y = t.y,
			tm = t.targetMode :: string,
			inv = t.invested,
			cp = t.circuitPartnerId,
			ci = t.circuitId,
			du = t.dustUntil,
			dis = t.disabledUntil,
			dr = if t.disabledUntil > state.simTime then t.disabledReason else nil,
		})
	end
	return list
end

function Snapshot.participants(state: Types.MatchState): { Types.ParticipantSnapshot }
	local list: { Types.ParticipantSnapshot } = {}
	for _, p in ipairs(state.participants) do
		table.insert(list, {
			userId = p.userId,
			name = p.displayName,
			connected = p.connected,
			ready = p.ready,
			speedVote = p.speedVote,
			color = participantColor(state, p.userId),
		})
	end
	return list
end

function Snapshot.build(state: Types.MatchState, forUserId: number, full: boolean): Types.MatchSnapshot
	local nextWave: { Types.WaveGroup }? = nil
	local previewIndex = if state.phase == "Preparation" then 1 else state.waveIndex + 1
	local def = Simulation.getWaveDef(state, previewIndex)
	if def then
		nextWave = def.groups
	end
	return {
		matchId = state.matchId,
		mode = state.mode,
		mapId = state.mapId,
		difficulty = state.difficulty,
		phase = state.phase,
		waveIndex = state.waveIndex,
		totalWaves = state.totalWaves,
		baseHP = state.baseHP,
		simTime = state.simTime,
		speedMultiplier = state.speedMultiplier,
		phaseEndsAt = state.phaseEndsAt,
		pulseReadyAt = state.pulseReadyAt,
		revision = state.revision,
		enemies = Snapshot.enemies(state),
		towers = if full then Snapshot.towers(state) else {},
		participants = Snapshot.participants(state),
		wallet = state.wallets[forUserId] or 0,
		limits = {
			perPlayer = Simulation.towerLimitPerPlayer(state),
			placedByMe = Simulation.countTowersOwned(state, forUserId, nil),
		},
		result = state.result,
		full = full,
		nextWavePreview = nextWave,
		trainingUnlockAll = state.trainingUnlockAll,
		levelId = state.levelId,
		-- eco do que vale estrela: o HUD mostra o progresso sem esperar o fim da partida
		damageTaken = state.campaignStats.damageTaken,
		towersBuilt = state.campaignStats.towersBuilt,
		wavesRushed = state.campaignStats.wavesRushed,
		retryAvailable = Simulation.canRetry(state),
		lostAtWave = state.lostAtWave,
		supportAvailable = Simulation.canUseSupport(state, forUserId),
		assisted = state.assisted,
	}
end

return Snapshot
