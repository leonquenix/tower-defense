local Simulation = load("Shared/Sim/Simulation")
local Balance = load("Shared/Config/Balance")
local Catalog = load("Shared/Config/Catalog")
local Stars = load("Shared/Rules/Stars")

local STARTERS = { "dardo", "pipoca", "goma" }

local function participant(userId)
	return {
		userId = userId,
		connected = true,
		active = true,
		ready = false,
		speedVote = 1,
		loadout = STARTERS,
		displayName = "P" .. userId,
	}
end

local function newMatch(opts)
	opts = opts or {}
	local parts = {}
	for i = 1, (opts.players or 1) do
		table.insert(parts, participant(100 * i))
	end
	local level = opts.level or Balance.campaign.levels[2]
	return Simulation.new({
		matchId = "m-monet",
		configVersion = "test",
		mode = "normal",
		mapId = level.mapId,
		difficulty = "normal",
		participants = parts,
		seed = 1,
		levelId = level.id,
		waves = level.waves,
		hpScale = level.hpScale,
		startingCash = level.startingCash,
		manualWaveStart = level.manualWaveStart,
		bossHpScale = level.bossHpScale,
		retryAllowed = opts.retry ~= false,
		supportAllowed = opts.support ~= false,
	})
end

local function startFirstWave(s)
	for _, p in ipairs(s.participants) do
		Simulation.setReady(s, p.userId, true)
	end
	Simulation.step(s)
end

-- Faz o Farol apagar no próximo passo: um inimigo na boca do Farol e vida mínima.
local function loseNow(s)
	s.baseHP = 1
	local steps = 0
	while s.phase == "Wave" and #s.enemyOrder == 0 and steps < 400 do
		Simulation.step(s)
		steps += 1
	end
	local id = s.enemyOrder[1]
	s.enemies[id].s = s.pathLength - 0.001
	Simulation.step(s)
end

describe("Retomada", function()
	it("o Farol apagado congela a partida em decisão, sem derrota ainda", function()
		local s = newMatch()
		startFirstWave(s)
		expect(s.checkpoint).toBeTruthy()
		expect(s.checkpoint.waveIndex).toBe(1)
		loseNow(s)
		expect(s.phase).toBe("RetryDecision")
		expect(s.lostAtWave).toBe(1)
		expect(s.result).toBeNil()
		expect(Simulation.canRetry(s)).toBe(true)
		-- o tempo de simulação não anda enquanto se decide
		local before = s.simTime
		Simulation.step(s)
		expect(s.simTime).toBe(before)
		expect(#s.enemyOrder).toBe(0)
	end)

	it("repete a onda com torres e carteira do início dela e o Farol cheio", function()
		local s = newMatch()
		expect(Simulation.placeTower(s, 100, "dardo", 4, 3).ok).toBe(true)
		startFirstWave(s)
		-- a foto é tirada já com o bônus de adiantar a onda
		local walletAtStart = s.wallets[100]
		-- gastos depois da foto não sobrevivem à Retomada
		expect(Simulation.placeTower(s, 100, "pipoca", 5, 3).ok).toBe(true)
		expect(#s.towerOrder).toBe(2)
		loseNow(s)
		local cr = Simulation.applyRetry(s)
		expect(cr.ok).toBe(true)
		expect(s.phase).toBe("Intermission")
		expect(s.waveIndex).toBe(0)
		expect(s.baseHP).toBe(Balance.baseHP)
		expect(#s.towerOrder).toBe(1)
		expect(s.wallets[100]).toBe(walletAtStart)
		expect(s.retryUsed).toBe(true)
		expect(s.assisted).toBe(true)
		-- a preparação curta leva de volta à mesma onda
		for _ = 1, math.ceil(Balance.shop.retry.prepSeconds * 20) + 2 do
			Simulation.step(s)
		end
		expect(s.phase).toBe("Wave")
		expect(s.waveIndex).toBe(1)
	end)

	it("uma por partida: a segunda derrota é definitiva", function()
		local s = newMatch()
		startFirstWave(s)
		loseNow(s)
		expect(Simulation.applyRetry(s).ok).toBe(true)
		expect(Simulation.applyRetry(s).ok).toBe(false)
		startFirstWave(s)
		for _ = 1, 200 do
			Simulation.step(s)
		end
		loseNow(s)
		expect(s.phase).toBe("Lost")
		expect(s.result.outcome).toBe("lost")
	end)

	it("recusar vira derrota normal com a recompensa de derrota", function()
		local s = newMatch()
		startFirstWave(s)
		loseNow(s)
		expect(Simulation.declineRetry(s).ok).toBe(true)
		expect(s.phase).toBe("Lost")
		expect(s.result.wavesCompleted).toBe(0)
		expect(Simulation.declineRetry(s).ok).toBe(false)
	end)

	it("partida sem Retomada permitida perde na hora", function()
		local s = newMatch({ retry = false })
		startFirstWave(s)
		expect(s.checkpoint).toBeNil()
		loseNow(s)
		expect(s.phase).toBe("Lost")
	end)

	it("ids e relógio não voltam no tempo", function()
		local s = newMatch()
		startFirstWave(s)
		loseNow(s)
		local nextId, rev, t = s.nextEntityId, s.revision, s.simTime
		Simulation.applyRetry(s)
		expect(s.nextEntityId >= nextId).toBe(true)
		expect(s.revision > rev).toBe(true)
		expect(s.simTime).toBe(t)
	end)
end)

describe("Reforço", function()
	it("coloca uma torre de graça só na preparação, uma vez por jogador", function()
		local s = newMatch()
		local wallet = s.wallets[100]
		expect(Simulation.canUseSupport(s, 100)).toBe(true)
		local cr = Simulation.placeTower(s, 100, "pipoca", 4, 3, { free = true })
		expect(cr.ok).toBe(true)
		expect(s.wallets[100]).toBe(wallet)
		expect(s.towers[cr.entityId].invested).toBe(0)
		expect(s.assisted).toBe(true)
		expect(Simulation.canUseSupport(s, 100)).toBe(false)
		expect(Simulation.placeTower(s, 100, "dardo", 5, 3, { free = true }).ok).toBe(false)
	end)

	it("vender a torre do Reforço devolve só o que foi pago em melhorias", function()
		local s = newMatch()
		local cr = Simulation.placeTower(s, 100, "dardo", 4, 3, { free = true })
		local id = cr.entityId
		expect(Simulation.upgradeTower(s, 100, id, "L1").ok).toBe(true)
		local walletBefore = s.wallets[100]
		local paid = Catalog.getStateStats("dardo", "L1").cost
		Simulation.sellTower(s, 100, id)
		expect(s.wallets[100] - walletBefore).toBe(math.floor(paid * Balance.sellRefund))
	end)

	it("depois que a onda começa, não há mais Reforço", function()
		local s = newMatch()
		startFirstWave(s)
		expect(Simulation.canUseSupport(s, 100)).toBe(false)
		expect(Simulation.placeTower(s, 100, "dardo", 4, 3, { free = true }).ok).toBe(false)
	end)

	it("partida sem Reforço permitido recusa a torre grátis", function()
		local s = newMatch({ support = false })
		expect(Simulation.placeTower(s, 100, "dardo", 4, 3, { free = true }).ok).toBe(false)
	end)

	it("vitória com ajuda abre a fase, mas não dá estrela de objetivo", function()
		local level = Balance.campaign.levels[2]
		local stats = {
			damageTaken = 0,
			towersBuilt = 2,
			towerIds = { dardo = true },
			wavesRushed = 0,
			wavesTotal = level.waves,
			towersSold = 0,
			circuitsActive = 0,
		}
		expect(Stars.evaluate(level, true, stats, false).stars).toBe(3)
		local assisted = Stars.evaluate(level, true, stats, true)
		expect(assisted.stars).toBe(1)
		expect(assisted.earned[1]).toBe(true)
	end)
end)

describe("Chefe no fim do mapa", function()
	it("a fase com bossHpScale traz o chefe depois da última onda, com a vida escalada", function()
		local level = Balance.campaign.levels[5]
		expect(level.bossHpScale).toBeTruthy()
		local s = newMatch({ level = level })
		s.phase = "Wave"
		s.waveIndex = level.waves
		s.waveRuntime.groupIndex = #Balance.waves[level.waves].groups
		s.waveRuntime.spawnedInGroup = Balance.waves[level.waves].groups[#Balance.waves[level.waves].groups].count - 1
		s.waveRuntime.nextSpawnAt = 0
		Simulation.step(s)
		expect(s.waveRuntime.bossScheduledAt).toBeTruthy()
		for _ = 1, 60 do
			Simulation.step(s)
		end
		local boss = nil
		for _, id in ipairs(s.enemyOrder) do
			if s.enemies[id].isBoss then
				boss = s.enemies[id]
			end
		end
		expect(boss).toBeTruthy()
		local def = Catalog.getBoss(Catalog.getMap(level.mapId).boss)
		expect(boss.maxHp).toBe(math.ceil(def.hp * level.hpScale * level.bossHpScale))
	end)

	it("fase sem bossHpScale termina sem chefe", function()
		local level = Balance.campaign.levels[2]
		local s = newMatch({ level = level })
		s.phase = "Wave"
		s.waveIndex = level.waves
		s.waveRuntime.groupIndex = #Balance.waves[level.waves].groups
		s.waveRuntime.spawnedInGroup = Balance.waves[level.waves].groups[#Balance.waves[level.waves].groups].count - 1
		s.waveRuntime.nextSpawnAt = 0
		Simulation.step(s)
		expect(s.waveRuntime.bossScheduledAt).toBeNil()
	end)
end)

describe("Objetivos novos", function()
	local function stats(over)
		local base = {
			damageTaken = 0,
			towersBuilt = 0,
			towerIds = {},
			wavesRushed = 0,
			wavesTotal = 5,
			towersSold = 0,
			circuitsActive = 0,
		}
		for k, v in pairs(over or {}) do
			base[k] = v
		end
		return base
	end
	it("noSell: nenhuma torre vendida", function()
		expect(Stars.objectiveMet({ kind = "noSell" }, stats())).toBe(true)
		expect(Stars.objectiveMet({ kind = "noSell" }, stats({ towersSold = 1 }))).toBe(false)
	end)
	it("minCircuits: circuitos ligados no fim", function()
		expect(Stars.objectiveMet({ kind = "minCircuits", value = 1 }, stats({ circuitsActive = 1 }))).toBe(true)
		expect(Stars.objectiveMet({ kind = "minCircuits", value = 2 }, stats({ circuitsActive = 1 }))).toBe(false)
	end)
	it("a partida conta vendas e circuitos ligados", function()
		local s = newMatch({ support = false })
		local a = Simulation.placeTower(s, 100, "dardo", 4, 3)
		Simulation.placeTower(s, 100, "goma", 5, 3)
		expect(s.towers[a.entityId].circuitId).toBeTruthy()
		Simulation.devFinish(s, "won")
		expect(s.result.campaignStats.circuitsActive).toBe(1)
		local t = newMatch({ support = false })
		local b = Simulation.placeTower(t, 100, "dardo", 4, 3)
		Simulation.sellTower(t, 100, b.entityId)
		expect(t.campaignStats.towersSold).toBe(1)
	end)
end)
