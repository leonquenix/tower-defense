local Simulation = load("Shared/Sim/Simulation")
local Balance = load("Shared/Config/Balance")
local Catalog = load("Shared/Config/Catalog")
local Combat = load("Shared/Rules/Combat")

local STARTERS = { "dardo", "pipoca", "goma" }

local function participant(userId, loadout)
	return {
		userId = userId,
		connected = true,
		active = true,
		ready = false,
		speedVote = 1,
		loadout = loadout or STARTERS,
		displayName = "P" .. userId,
	}
end

local function newMatch(opts)
	opts = opts or {}
	local parts = {}
	for i = 1, (opts.players or 1) do
		table.insert(parts, participant(100 * i, opts.loadout))
	end
	return Simulation.new({
		matchId = "m-test",
		configVersion = "test",
		mode = opts.mode or "normal",
		mapId = opts.mapId or "jardim",
		difficulty = opts.difficulty or "normal",
		participants = parts,
		seed = 1,
	})
end

local function runSteps(state, n)
	local all = {}
	for _ = 1, n do
		for _, e in ipairs(Simulation.step(state)) do
			table.insert(all, e)
		end
		if Simulation.isTerminal(state) then
			break
		end
	end
	return all
end

local function skipPreparation(state)
	Simulation.setReady(state, state.participantOrder[1], true)
	for _, p in ipairs(state.participants) do
		Simulation.setReady(state, p.userId, true)
	end
	Simulation.step(state)
end

local function firstEnemy(state)
	return state.enemies[state.enemyOrder[1]]
end

describe("Simulation / comandos", function()
	it("T01: colocar Dardo com 650 sucatas deixa 400 e uma torre L0", function()
		local s = newMatch()
		local r = Simulation.placeTower(s, 100, "dardo", 3, 3)
		expect(r.ok).toBe(true)
		expect(r.balance).toBe(400)
		expect(#s.towerOrder).toBe(1)
		expect(s.towers[r.entityId].state).toBe("L0")
	end)
	it("T03: dois jogadores compram a mesma célula -> só a primeira é aceita", function()
		local s = newMatch({ players = 2 })
		local r1 = Simulation.placeTower(s, 100, "dardo", 3, 3)
		local r2 = Simulation.placeTower(s, 200, "dardo", 3, 3)
		expect(r1.ok).toBe(true)
		expect(r2.ok).toBe(false)
		expect(r2.errorCode).toBe("OCCUPIED")
		expect(s.wallets[200]).toBe(650)
	end)
	it("T04: colocar sobre caminho, bloqueio ou fora do mapa é rejeitado sem gasto", function()
		local s = newMatch()
		expect(Simulation.placeTower(s, 100, "dardo", 4, 4).errorCode).toBe("INVALID_CELL") -- caminho
		expect(Simulation.placeTower(s, 100, "dardo", 1, 8).errorCode).toBe("INVALID_CELL") -- bloqueio
		expect(Simulation.placeTower(s, 100, "dardo", 16, 0).errorCode).toBe("INVALID_CELL") -- fora
		expect(Simulation.placeTower(s, 100, "dardo", 2.5, 1).errorCode).toBe("INVALID_CELL") -- não inteiro
		expect(s.wallets[100]).toBe(650)
	end)
	it("T05: comprar L2 diretamente de L0 -> INVALID_STATE", function()
		local s = newMatch()
		local r = Simulation.placeTower(s, 100, "dardo", 3, 3)
		local up = Simulation.upgradeTower(s, 100, r.entityId, "L2")
		expect(up.errorCode).toBe("INVALID_STATE")
		expect(s.wallets[100]).toBe(400)
	end)
	it("T06: Dardo L0+L1 comprados e vendidos -> investido 450, devolução 315", function()
		local s = newMatch()
		local r = Simulation.placeTower(s, 100, "dardo", 3, 3)
		expect(Simulation.upgradeTower(s, 100, r.entityId, "L1").ok).toBe(true)
		expect(s.towers[r.entityId].invested).toBe(450)
		expect(s.wallets[100]).toBe(200)
		local sell = Simulation.sellTower(s, 100, r.entityId)
		expect(sell.ok).toBe(true)
		expect(s.wallets[100]).toBe(515)
		expect(#s.towerOrder).toBe(0)
	end)
	it("P10: vender torre alheia -> NOT_OWNER", function()
		local s = newMatch({ players = 2 })
		local r = Simulation.placeTower(s, 100, "dardo", 3, 3)
		expect(Simulation.sellTower(s, 200, r.entityId).errorCode).toBe("NOT_OWNER")
		expect(Simulation.upgradeTower(s, 200, r.entityId, "L1").errorCode).toBe("NOT_OWNER")
		expect(Simulation.setTarget(s, 200, r.entityId, "last").errorCode).toBe("NOT_OWNER")
	end)
	it("torre não equipada é recusada; treino libera todas", function()
		local s = newMatch()
		expect(Simulation.placeTower(s, 100, "voltz", 3, 3).errorCode).toBe("INVALID_STATE")
		local t = newMatch({ mode = "training" })
		expect(Simulation.placeTower(t, 100, "voltz", 3, 3).ok).toBe(true)
		expect(t.wallets[100]).toBe(650)
	end)
	it("limites por pessoa e por espécie", function()
		local s = newMatch({ players = 4 })
		s.wallets[100] = 100000
		local placed = 0
		for x = 0, 15 do
			for y = 0, 9 do
				if placed < 8 then
					local r = Simulation.placeTower(s, 100, "dardo", x, y)
					if r.ok then
						placed += 1
					end
				end
			end
		end
		-- 6 Dardos no máximo por pessoa
		expect(Simulation.countTowersOwned(s, 100, "dardo")).toBe(6)
		-- completa até 8 com Pipoca
		local ok = 0
		for x = 0, 15 do
			for y = 0, 9 do
				local r = Simulation.placeTower(s, 100, "pipoca", x, y)
				if r.ok then
					ok += 1
				end
			end
		end
		expect(Simulation.countTowersOwned(s, 100)).toBe(8)
		local last = nil
		for x = 0, 15 do
			for y = 0, 9 do
				local r = Simulation.placeTower(s, 100, "goma", x, y)
				if r.errorCode == "LIMIT_REACHED" then
					last = r
				end
			end
		end
		expect(last).toBeTruthy()
	end)
	it("saldo insuficiente é recusado sem gasto", function()
		local s = newMatch()
		s.wallets[100] = 100
		expect(Simulation.placeTower(s, 100, "dardo", 3, 3).errorCode).toBe("INSUFFICIENT_FUNDS")
		expect(s.wallets[100]).toBe(100)
	end)
end)

describe("Simulation / vida e chefes", function()
	it("T18: Fiapo no Jardim Normal com quatro pessoas tem vida ceil(24 x 3,1) = 75", function()
		local s = newMatch({ players = 4 })
		skipPreparation(s)
		local e = firstEnemy(s)
		expect(e.defId).toBe("fiapo")
		expect(e.hp).toBe(75)
	end)
	it("T19: Aspirador no Jardim Desafio solo tem vida ceil(7000 x 1,45) = 10150", function()
		local s = newMatch({ difficulty = "desafio" })
		expect(math.ceil(Catalog.getBoss("aspirador").hp * s.bossHpFactor)).toBe(10150)
	end)
	it("mapa multiplica vida comum mas não a do chefe", function()
		local s = newMatch({ mapId = "sotao", players = 2 })
		expect(s.commonHpFactor).toBeCloseTo(1.25 * 1.7)
		expect(s.bossHpFactor).toBeCloseTo(1.7)
	end)
	it("Desafio aumenta velocidade em 10%", function()
		local s = newMatch({ difficulty = "desafio" })
		skipPreparation(s)
		expect(firstEnemy(s).baseSpeed).toBeCloseTo(1.25 * 1.1)
	end)
end)

describe("Simulation / Circuitos e efeitos em partida", function()
	it("T12: vender parceiro conectado remove o bônus no mesmo passo", function()
		local s = newMatch()
		s.wallets[100] = 5000
		local d = Simulation.placeTower(s, 100, "dardo", 3, 3)
		local g = Simulation.placeTower(s, 100, "goma", 3, 4)
		expect(s.towers[d.entityId].circuitPartnerId).toBe(g.entityId)
		local _, events = Simulation.sellTower(s, 100, g.entityId)
		expect(s.towers[d.entityId].circuitPartnerId).toBeNil()
		local found = false
		for _, e in ipairs(events) do
			if e.kind == "circuitChanged" and e.towerId == d.entityId then
				found = true
			end
		end
		expect(found).toBe(true)
	end)
	it("Pega e acerta: Dardo causa 15% a mais em alvo lento", function()
		local s = newMatch()
		s.wallets[100] = 5000
		local d = Simulation.placeTower(s, 100, "dardo", 3, 3)
		Simulation.placeTower(s, 100, "goma", 3, 4)
		skipPreparation(s)
		-- avança até o primeiro Fiapo estar em alcance e lento
		local events = runSteps(s, 200)
		local bonusHit, plainHit = nil, nil
		for _, e in ipairs(events) do
			if e.kind == "attack" and e.towerId == d.entityId then
				local dmg = e.targets[1].damage
				if math.abs(dmg - 11.5) < 1e-6 then
					bonusHit = dmg
				end
				if math.abs(dmg - 10) < 1e-6 then
					plainHit = dmg
				end
			end
		end
		expect(bonusHit).toBe(11.5)
	end)
	it("T17: dois jogadores usam Pulso no mesmo passo -> um efeito e uma recarga", function()
		local s = newMatch({ players = 2 })
		skipPreparation(s)
		runSteps(s, 10)
		local r1, ev1 = Simulation.castPulse(s, 100)
		local r2, ev2 = Simulation.castPulse(s, 200)
		expect(r1.ok).toBe(true)
		expect(r2.ok).toBe(false)
		expect(#ev1).toBe(1)
		expect(#ev2).toBe(0)
		expect(s.pulseReadyAt).toBeCloseTo(s.simTime + 60)
	end)
	it("Pulso causa 180 x coop de energia e aplica lentidão", function()
		local s = newMatch({ players = 3 })
		skipPreparation(s)
		runSteps(s, 5)
		local e = firstEnemy(s)
		local hpBefore = e.hp
		local _, ev = Simulation.castPulse(s, 100)
		expect(ev[1].amount).toBeCloseTo(180 * 2.4)
		expect(e.hp).toBeCloseTo(hpBefore - 180 * 2.4)
		expect(Combat.activeSlow(e, s.simTime, Balance.effects)).toBeCloseTo(0.3)
	end)
	it("Pulso fora da onda é recusado", function()
		local s = newMatch()
		expect(Simulation.castPulse(s, 100).errorCode).toBe("INVALID_STATE")
	end)
end)

describe("Simulation / Casulo, Remendo e recompensas", function()
	local function spawnAt(state, defId, s, overrides)
		-- usa o treino para gerar inimigos específicos; congela o roteiro da onda
		state.waveRuntime.nextSpawnAt = math.huge
		state.mode = "training"
		local r = Simulation.trainingSpawn(state, defId, 1)
		Simulation.step(state)
		state.mode = "normal"
		local e = state.enemies[state.enemyOrder[#state.enemyOrder]]
		e.s = s or 0
		return e
	end
	it("T14: Casulo morto cria três Fiapos sem bounty; um bounty de Casulo", function()
		local s = newMatch({ players = 1 })
		s.phase = "Wave"
		s.waveIndex = 1
		local casulo = spawnAt(s, "casulo", 5)
		local before = s.wallets[100]
		casulo.hp = 0
		local events = Simulation.step(s)
		expect(s.wallets[100]).toBe(before + 30)
		expect(#s.enemyOrder).toBe(3)
		for _, id in ipairs(s.enemyOrder) do
			local child = s.enemies[id]
			expect(child.defId).toBe("fiapo")
			expect(child.bounty).toBe(0)
			expect(child.isSummon).toBe(true)
			expect(child.leak).toBe(1)
			expect(child.hp).toBe(12)
			expect(child.baseSpeed).toBeCloseTo(1.6)
		end
		-- matar filhos não paga
		for _, id in ipairs(table.clone(s.enemyOrder)) do
			s.enemies[id].hp = 0
		end
		Simulation.step(s)
		expect(s.wallets[100]).toBe(before + 30)
	end)
	it("T15: Casulo que vaza causa um leak e nenhum filho", function()
		local s = newMatch()
		s.phase = "Wave"
		s.waveIndex = 1
		local casulo = spawnAt(s, "casulo", s.pathLength - 0.01)
		local hp = s.baseHP
		Simulation.step(s)
		expect(s.baseHP).toBe(hp - 8)
		expect(#s.enemyOrder).toBe(0)
	end)
	it("Remendo cura aliados comuns a cada 3 s, sem curar chefes ou outros Remendos", function()
		local s = newMatch()
		s.phase = "Wave"
		s.waveIndex = 1
		local remendo = spawnAt(s, "remendo", 5)
		local fiapo = spawnAt(s, "fiapo", 5.5)
		local outro = spawnAt(s, "remendo", 5.2)
		fiapo.hp = 1
		outro.hp = 1
		remendo.lastHealAt = s.simTime - 3
		outro.lastHealAt = s.simTime - 3
		-- impede movimento para fora do raio
		fiapo.baseSpeed = 0
		remendo.baseSpeed = 0
		outro.baseSpeed = 0
		Simulation.step(s)
		expect(fiapo.hp).toBe(13) -- 1 + 12 x fator 1, um único pulso mesmo com dois curadores
		expect(outro.hp).toBe(1)
	end)
	it("bounty de Fiapo (8) com dois participantes divide 4 e 4", function()
		local s = newMatch({ players = 2 })
		s.phase = "Wave"
		s.waveIndex = 1
		local f = spawnAt(s, "fiapo", 3)
		f.hp = 0
		Simulation.step(s)
		expect(s.wallets[100]).toBe(654)
		expect(s.wallets[200]).toBe(654)
	end)
end)

describe("Simulation / partida curta até vitória e derrota", function()
	it("T16: base zera no passo em que o último inimigo morreria -> derrota prevalece", function()
		local s = newMatch()
		s.phase = "Wave"
		s.waveIndex = 20
		s.waveRuntime.allGroupsSpawned = true
		s.waveRuntime.bossSpawned = true
		s.waveRuntime.bossScheduledAt = 0
		s.baseHP = 1
		s.mode = "training"
		Simulation.trainingSpawn(s, "fiapo", 1)
		Simulation.step(s)
		s.mode = "normal"
		local e = firstEnemy(s)
		e.s = s.pathLength - 0.001
		e.hp = 0 -- morreria na etapa de mortes, mas vaza na etapa de movimento
		Simulation.step(s)
		expect(s.phase).toBe("Lost")
		expect(s.result.outcome).toBe("lost")
	end)
	it("sem torres, o Jardim é perdido antes da onda 20", function()
		local s = newMatch()
		skipPreparation(s)
		runSteps(s, 20 * 60 * 20)
		expect(s.phase).toBe("Lost")
		expect(s.result.buttonsPerPlayer).toBe(math.min(4 * s.result.wavesCompleted, 60))
	end)
	it("tutorial: três ondas com equipe inicial guiada termina em vitória e 180 botões", function()
		local s = newMatch({ mode = "tutorial" })
		expect(s.wallets[100]).toBe(1200)
		expect(s.totalWaves).toBe(3)
		expect(Simulation.placeTower(s, 100, "dardo", 3, 3).ok).toBe(true)
		expect(Simulation.placeTower(s, 100, "goma", 3, 4).ok).toBe(true)
		expect(Simulation.placeTower(s, 100, "pipoca", 5, 5).ok).toBe(true)
		local d = s.towerOrder[1]
		expect(Simulation.upgradeTower(s, 100, d, "L1").ok).toBe(true)
		-- no tutorial cada fase de espera exige Pronto
		for _ = 1, 10 * 60 * 20 do
			if s.phase == "Preparation" or s.phase == "Intermission" then
				Simulation.setReady(s, 100, true)
			end
			Simulation.step(s)
			if Simulation.isTerminal(s) then
				break
			end
		end
		expect(s.phase).toBe("Won")
		expect(s.result.wavesCompleted).toBe(3)
		expect(s.result.buttonsPerPlayer).toBe(180)
		expect(s.baseHP).toBeGreaterThan(0)
	end)
	it("tutorial não inicia onda pelo cronômetro; só com Pronto", function()
		local s = newMatch({ mode = "tutorial" })
		runSteps(s, 40 * 20)
		expect(s.phase).toBe("Preparation")
		expect(#s.enemyOrder).toBe(0)
		Simulation.setReady(s, 100, true)
		Simulation.step(s)
		expect(s.phase).toBe("Wave")
	end)
	it("2x exige unanimidade e tutorial fica em 1x", function()
		local s = newMatch({ players = 2 })
		Simulation.voteSpeed(s, 100, 2)
		expect(s.speedMultiplier).toBe(1)
		Simulation.voteSpeed(s, 200, 2)
		expect(s.speedMultiplier).toBe(2)
		Simulation.voteSpeed(s, 100, 1)
		expect(s.speedMultiplier).toBe(1)
		local t = newMatch({ mode = "tutorial" })
		expect(Simulation.voteSpeed(t, 100, 2).ok).toBe(false)
	end)
	it("participante ausente há 30 s deixa de contar para unanimidade", function()
		local s = newMatch({ players = 2 })
		Simulation.voteSpeed(s, 100, 2)
		Simulation.setParticipantPresence(s, 200, false, false)
		expect(s.speedMultiplier).toBe(2)
		Simulation.setReady(s, 100, true)
		Simulation.step(s)
		expect(s.phase).toBe("Wave")
	end)
end)
