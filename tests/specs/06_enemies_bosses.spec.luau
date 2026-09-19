-- Casos de aceite do GUIA_MONSTROS_E_BOSSES (páginas 4 a 14 e tabela da página 17).
-- Verificam o comportamento autoritativo do servidor: atributos, resistências, cura, divisão,
-- ciclos dos chefes, invocações, recompensas únicas e encerramento de onda.
local Simulation = load("Shared/Sim/Simulation")
local Snapshot = load("Shared/Sim/Snapshot")
local Balance = load("Shared/Config/Balance")
local Catalog = load("Shared/Config/Catalog")
local Combat = load("Shared/Rules/Combat")

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
	return Simulation.new({
		matchId = "m-enemy",
		configVersion = "test",
		mode = opts.mode or "normal",
		mapId = opts.mapId or "jardim",
		difficulty = opts.difficulty or "normal",
		participants = parts,
		seed = 1,
	})
end

-- Gera um inimigo específico pelo caminho de treino (mesma convenção de 03_simulation),
-- congelando o roteiro da onda. overrides ajusta os campos que o servidor define em invocações.
local function spawn(state, defId, s, overrides)
	local mode = state.mode
	state.waveRuntime.nextSpawnAt = math.huge
	-- a fila de treino só é drenada em fase de combate; o estado fica em Wave para que os passos
	-- seguintes do teste avancem movimento, cura e chefes (waveIndex 0 não agenda grupos)
	state.mode = "training"
	state.phase = "Wave"
	Simulation.trainingSpawn(state, defId, 1)
	Simulation.step(state)
	state.mode = mode
	local e = state.enemies[state.enemyOrder[#state.enemyOrder]]
	e.s = s or 0
	if overrides then
		if overrides.hp then
			e.hp = overrides.hp
			e.maxHp = overrides.hp
		end
		if overrides.speed then
			e.baseSpeed = overrides.speed
		end
		if overrides.leak then
			e.leak = overrides.leak
		end
		if overrides.bounty ~= nil then
			e.bounty = overrides.bounty
		end
		if overrides.isSummon ~= nil then
			e.isSummon = overrides.isSummon
		end
	end
	return e
end

local function damage(enemy, amount, damageType, armorIgnore, simTime)
	return Combat.computeDamage({
		baseDamage = amount,
		damageType = damageType,
		armorIgnore = armorIgnore,
		mark = 0,
		armor = Combat.currentArmor(enemy, simTime or 0),
		energyResistance = enemy.energyResistance,
		isBoss = enemy.isBoss,
		armorCap = Balance.effects.physicalArmorCap,
	})
end

local function countOf(state, defId)
	local n = 0
	for _, id in ipairs(state.enemyOrder) do
		if state.enemies[id].defId == defId then
			n += 1
		end
	end
	return n
end

local function eventsOfKind(events, kind)
	local list = {}
	for _, e in ipairs(events) do
		if e.kind == kind then
			table.insert(list, e)
		end
	end
	return list
end

describe("Guia / atributos dos oito inimigos", function()
	it("catálogo bate com a tabela da página 2", function()
		local expected = {
			fiapo = { hp = 24, speed = 1.25, bounty = 8, leak = 2, armor = 0, energy = 0 },
			corrisco = { hp = 32, speed = 2.05, bounty = 10, leak = 3, armor = 0, energy = 0 },
			bolota = { hp = 150, speed = 0.85, bounty = 22, leak = 6, armor = 0, energy = 0 },
			latinha = { hp = 115, speed = 1, bounty = 20, leak = 5, armor = 0.45, energy = 0 },
			nevoa = { hp = 75, speed = 1.45, bounty = 17, leak = 4, armor = 0, energy = 0.35 },
			remendo = { hp = 180, speed = 1, bounty = 28, leak = 6, armor = 0, energy = 0 },
			casulo = { hp = 230, speed = 0.9, bounty = 30, leak = 8, armor = 0.15, energy = 0 },
			brutamontes = { hp = 600, speed = 0.65, bounty = 65, leak = 14, armor = 0.25, energy = 0 },
		}
		for id, want in pairs(expected) do
			local def = Catalog.getEnemy(id)
			expect(def ~= nil).toBe(true)
			expect(def.hp).toBe(want.hp)
			expect(def.speed).toBe(want.speed)
			expect(def.bounty).toBe(want.bounty)
			expect(def.leak).toBe(want.leak)
			expect(def.armor).toBe(want.armor)
			expect(def.energyResistance or 0).toBe(want.energy)
		end
	end)

	it("catálogo dos três chefes bate com a tabela da página 2", function()
		local expected = {
			aspirador = { hp = 7000, armor = 0.15, mechanic = "dust_pulse", period = 14 },
			rei_ferrugem = { hp = 8500, armor = 0.2, mechanic = "armor_cycle", period = 14 },
			breu = { hp = 10000, armor = 0.1, mechanic = "summon", period = 16 },
		}
		for id, want in pairs(expected) do
			local def = Catalog.getBoss(id)
			expect(def ~= nil).toBe(true)
			expect(def.hp).toBe(want.hp)
			expect(def.armor).toBe(want.armor)
			expect(def.mechanic).toBe(want.mechanic)
			expect(def.period).toBe(want.period)
			expect(def.speed).toBe(0.4)
			expect(def.leak).toBe(100)
			expect(def.bounty).toBe(0)
			expect(def.telegraph).toBe(2)
		end
	end)
end)

describe("Guia / resistências", function()
	it("Latinha: físico 20 -> 11; energia 20 -> 20; armorIgnore 1 -> 20", function()
		local s = newMatch()
		local e = spawn(s, "latinha")
		expect(damage(e, 20, "physical")).toBeCloseTo(11)
		expect(damage(e, 20, "energy")).toBeCloseTo(20)
		expect(damage(e, 20, "physical", 1)).toBeCloseTo(20)
	end)

	it("Névoa: energia 20 -> 13; físico 20 -> 20; Pulso de Luz solo -> 117", function()
		local s = newMatch()
		local e = spawn(s, "nevoa")
		expect(damage(e, 20, "energy")).toBeCloseTo(13)
		expect(damage(e, 20, "physical")).toBeCloseTo(20)
		expect(damage(e, Balance.pulse.damage, "energy")).toBeCloseTo(117)
	end)

	it("Bolota: sem redução em físico e energia", function()
		local s = newMatch()
		local e = spawn(s, "bolota")
		expect(damage(e, 20, "physical")).toBeCloseTo(20)
		expect(damage(e, 20, "energy")).toBeCloseTo(20)
	end)

	it("Brutamontes: físico 20 -> 15; lentidão comum de 45% não vira 15,75%", function()
		local s = newMatch()
		local e = spawn(s, "brutamontes")
		expect(damage(e, 20, "physical")).toBeCloseTo(15)
		expect(damage(e, 20, "energy")).toBeCloseTo(20)
		Combat.applyEffect(e.slows, 0.45, 2, 1, s.simTime)
		expect(Combat.activeSlow(e, s.simTime, Balance.effects)).toBeCloseTo(0.45)
		local boss = spawn(s, "aspirador")
		Combat.applyEffect(boss.slows, 0.45, 2, 1, s.simTime)
		expect(Combat.activeSlow(boss, s.simTime, Balance.effects)).toBeCloseTo(0.1575)
	end)
end)

describe("Guia / escala de vida", function()
	it("Fiapo no Jardim Normal com quatro pessoas nasce com 75", function()
		local s = newMatch({ players = 4 })
		local e = spawn(s, "fiapo")
		expect(e.hp).toBe(75)
		expect(e.maxHp).toBe(75)
	end)

	it("Aspirador solo no Desafio nasce com 10150 (mapa não conta para chefe)", function()
		local s = newMatch({ difficulty = "desafio", mapId = "sotao" })
		local boss = spawn(s, "aspirador")
		expect(boss.hp).toBe(10150)
	end)

	it("velocidade do Corrisco no Desafio é 2,255 e não muda por mapa", function()
		local s = newMatch({ difficulty = "desafio", mapId = "oficina" })
		local e = spawn(s, "corrisco")
		expect(e.baseSpeed).toBeCloseTo(2.255)
	end)
end)

describe("Guia / Remendo", function()
	it("dois Remendos no mesmo passo curam Fiapo 10/24 para 22/24", function()
		local s = newMatch()
		local target = spawn(s, "fiapo", 3)
		target.hp = 10
		local h1 = spawn(s, "remendo", 3)
		local h2 = spawn(s, "remendo", 3)
		-- primeiro pulso em nascimento + 3 s (decisão de implementação registrada no guia)
		h1.lastHealAt = s.simTime - 3
		h2.lastHealAt = s.simTime - 3
		Simulation.step(s)
		expect(target.hp).toBeCloseTo(22)
		expect(target.hp < target.maxHp).toBe(true)
	end)

	it("não cura a si mesmo, outro Remendo nem chefe", function()
		local s = newMatch()
		local healer = spawn(s, "remendo", 3)
		local other = spawn(s, "remendo", 3)
		local boss = spawn(s, "aspirador", 3)
		healer.hp = 50
		other.hp = 50
		boss.hp = 100
		healer.lastHealAt = s.simTime - 3
		other.lastHealAt = s.simTime - 3
		Simulation.step(s)
		expect(healer.hp).toBeCloseTo(50)
		expect(other.hp).toBeCloseTo(50)
		expect(boss.hp).toBeCloseTo(100)
	end)

	it("pulso vale 12 x fator de vida comum e o evento lista os alvos curados", function()
		local s = newMatch({ players = 4, mapId = "sotao" }) -- fator 1,25 x 3,1
		local target = spawn(s, "fiapo", 3)
		target.hp = 1
		local healer = spawn(s, "remendo", 3)
		healer.lastHealAt = s.simTime - 3
		local events = Simulation.step(s)
		local heals = eventsOfKind(events, "heal")
		expect(#heals).toBe(1)
		expect(heals[1].amount).toBeCloseTo(12 * s.commonHpFactor)
		expect(heals[1].entityIds[1]).toBe(target.id)
		expect(target.hp).toBeCloseTo(1 + 12 * s.commonHpFactor)
	end)

	it("filhos de Casulo e invocados de Breu são comuns e podem ser curados", function()
		local s = newMatch()
		local child = spawn(s, "fiapo", 3, { hp = 12, speed = 1.6, leak = 1, bounty = 0, isSummon = true })
		child.hp = 2
		local healer = spawn(s, "remendo", 3)
		healer.lastHealAt = s.simTime - 3
		Simulation.step(s)
		-- pulso de 12 sobre 2/12: cura limitada à vida máxima, sem ressuscitar nem ultrapassar
		expect(child.hp).toBeCloseTo(12)
		expect(child.hp).toBe(child.maxHp)
	end)
end)

describe("Guia / Casulo", function()
	it("morte letal gera exatamente três filhos, uma recompensa e sem bounty nos filhos", function()
		local s = newMatch()
		local casulo = spawn(s, "casulo", 3)
		casulo.hp = -5 -- dois ataques letais no mesmo passo continuam sendo uma morte
		local before = s.wallets[100]
		local events = Simulation.step(s)
		local deaths = eventsOfKind(events, "death")
		expect(#deaths).toBe(1)
		expect(s.wallets[100] - before).toBe(30)
		expect(countOf(s, "fiapo")).toBe(3)
		for _, id in ipairs(s.enemyOrder) do
			local child = s.enemies[id]
			expect(child.bounty).toBe(0)
			expect(child.isSummon).toBe(true)
			expect(child.hp).toBe(12)
			expect(child.leak).toBe(1)
			expect(child.baseSpeed).toBeCloseTo(1.6)
			expect(#child.slows).toBe(0) -- não herda efeitos do pai
		end
	end)

	it("Casulo que alcança a base causa 8, não divide e não paga", function()
		local s = newMatch()
		local casulo = spawn(s, "casulo", s.pathLength - 0.01)
		casulo.hp = 1
		local before = s.wallets[100]
		local baseBefore = s.baseHP
		local events = Simulation.step(s)
		expect(#eventsOfKind(events, "leak")).toBe(1)
		expect(baseBefore - s.baseHP).toBe(8)
		expect(s.wallets[100]).toBe(before)
		expect(countOf(s, "fiapo")).toBe(0)
	end)

	it("filhos entram após as mortes e a onda não termina antes de resolvê-los", function()
		local s = newMatch()
		s.phase = "Wave"
		s.waveIndex = 1
		s.waveRuntime.allGroupsSpawned = true
		local casulo = spawn(s, "casulo", 3)
		casulo.hp = 0
		Simulation.step(s)
		expect(s.phase).toBe("Wave")
		expect(#s.enemyOrder).toBe(3)
	end)
end)

describe("Guia / Aspirador", function()
	it("aviso aos 14 s, poeira aos 16 s por 4 s e intervalo 1 s vira 1,333 s", function()
		local s = newMatch()
		local boss = spawn(s, "aspirador", 1)
		local place = Simulation.placeTower(s, 100, "dardo", 4, 3)
		local tower = s.towers[place.entityId]
		boss.bossNextTelegraphAt = boss.spawnedAt + 14
		local telegraph, ability
		for _ = 1, 400 do
			local events = Simulation.step(s)
			for _, e in ipairs(events) do
				if e.kind == "bossTelegraph" then
					telegraph = telegraph or e
				elseif e.kind == "bossAbility" then
					ability = ability or e
				end
			end
			if ability then
				break
			end
		end
		expect(telegraph ~= nil).toBe(true)
		expect(ability ~= nil).toBe(true)
		expect(telegraph.simTime - boss.spawnedAt).toBeCloseTo(14, 0.06)
		expect(ability.simTime - boss.spawnedAt).toBeCloseTo(16, 0.06)
		expect(telegraph.resolveAt).toBeCloseTo(telegraph.simTime + 2, 1e-6)
		expect(ability.expiresAt).toBeCloseTo(ability.simTime + 4, 1e-6)
		expect(tower.dustUntil > s.simTime).toBe(true)
		-- cadência cai 25%: intervalo base / 0,75
		local base = Catalog.getStateStats("dardo", "L0").interval
		expect(Simulation.effectiveIntervalFor(s, tower)).toBeCloseTo(base / 0.75)
	end)

	it("centro fica fixo: vender a torre marcada durante o aviso não move a área", function()
		local s = newMatch()
		s.wallets[100] = 100000
		local boss = spawn(s, "aspirador", 1)
		local a = Simulation.placeTower(s, 100, "dardo", 4, 3)
		Simulation.upgradeTower(s, 100, a.entityId, "L1") -- maior sucata investida
		Simulation.placeTower(s, 100, "dardo", 12, 8)
		boss.bossNextTelegraphAt = s.simTime
		Simulation.step(s)
		expect(boss.bossTelegraphing).toBe(true)
		expect(boss.bossTargetCell[1]).toBe(4)
		expect(boss.bossTargetCell[2]).toBe(3)
		Simulation.sellTower(s, 100, a.entityId)
		for _ = 1, 45 do
			Simulation.step(s)
		end
		expect(boss.bossTargetCell[1]).toBe(4)
		expect(boss.bossTargetCell[2]).toBe(3)
	end)

	it("sem torres o ciclo é consumido sem área", function()
		local s = newMatch()
		local boss = spawn(s, "aspirador", 1)
		boss.bossNextTelegraphAt = s.simTime
		Simulation.step(s)
		expect(boss.bossTelegraphing).toBe(true)
		expect(boss.bossTargetCell).toBeNil()
		for _ = 1, 45 do
			Simulation.step(s)
		end
		expect(boss.bossTelegraphing).toBe(false)
	end)

	it("morte durante o aviso cancela a resolução e avisa o cliente", function()
		local s = newMatch()
		local boss = spawn(s, "aspirador", 1)
		Simulation.placeTower(s, 100, "dardo", 4, 3)
		boss.bossNextTelegraphAt = s.simTime
		Simulation.step(s)
		expect(boss.bossTelegraphing).toBe(true)
		boss.hp = 0
		local events = Simulation.step(s)
		expect(#eventsOfKind(events, "bossCancel")).toBe(1)
		local tower = s.towers[s.towerOrder[1]]
		for _ = 1, 45 do
			Simulation.step(s)
		end
		expect(tower.dustUntil <= 0).toBe(true)
	end)
end)

describe("Guia / Rei Ferrugem", function()
	it("20% antes, 55% por 5 s e 20% depois; físico 100 -> 80/45/80", function()
		local s = newMatch({ mapId = "oficina" })
		local boss = spawn(s, "rei_ferrugem", 1)
		expect(damage(boss, 100, "physical", nil, s.simTime)).toBeCloseTo(80)
		boss.bossNextTelegraphAt = s.simTime
		for _ = 1, 41 do -- 2 s de aviso
			Simulation.step(s)
		end
		expect(Combat.currentArmor(boss, s.simTime)).toBeCloseTo(0.55)
		expect(damage(boss, 100, "physical", nil, s.simTime)).toBeCloseTo(45)
		expect(damage(boss, 100, "energy", nil, s.simTime)).toBeCloseTo(100)
		for _ = 1, 101 do -- passa dos 5 s de reforço
			Simulation.step(s)
		end
		expect(Combat.currentArmor(boss, s.simTime)).toBeCloseTo(0.2)
		expect(damage(boss, 100, "physical", nil, s.simTime)).toBeCloseTo(80)
	end)

	it("eventos duplicados não acumulam além de 55%", function()
		local s = newMatch({ mapId = "oficina" })
		local boss = spawn(s, "rei_ferrugem", 1)
		boss.bossNextTelegraphAt = s.simTime
		for _ = 1, 41 do
			Simulation.step(s)
		end
		local armor = Combat.currentArmor(boss, s.simTime)
		boss.bossNextTelegraphAt = s.simTime
		for _ = 1, 41 do
			Simulation.step(s)
		end
		expect(Combat.currentArmor(boss, s.simTime)).toBeCloseTo(armor)
		expect(Combat.currentArmor(boss, s.simTime)).toBeCloseTo(0.55)
	end)
end)

describe("Guia / Breu", function()
	it("invoca quatro Corriscos sem recompensa em s + 0,5", function()
		local s = newMatch({ mapId = "sotao" })
		local boss = spawn(s, "breu", 2)
		boss.bossNextTelegraphAt = s.simTime
		local ability
		for _ = 1, 60 do
			for _, e in ipairs(Simulation.step(s)) do
				if e.kind == "bossAbility" then
					ability = ability or e
				end
			end
			if ability then
				break
			end
		end
		expect(ability ~= nil).toBe(true)
		expect(#ability.entityIds).toBe(4)
		expect(countOf(s, "corrisco")).toBe(4)
		for _, id in ipairs(ability.entityIds) do
			local summon = s.enemies[id]
			expect(summon.bounty).toBe(0)
			expect(summon.isSummon).toBe(true)
			expect(summon.leak).toBe(3) -- mantém o leak de Corrisco comum
			expect(summon.s).toBeCloseTo(math.min(ability.s + 0.5, s.pathLength - 0.1), 0.06)
		end
	end)

	it("morto durante o aviso não invoca; morto depois não apaga os invocados", function()
		local s = newMatch({ mapId = "sotao" })
		local boss = spawn(s, "breu", 2)
		boss.bossNextTelegraphAt = s.simTime
		Simulation.step(s)
		expect(boss.bossTelegraphing).toBe(true)
		boss.hp = 0
		Simulation.step(s)
		for _ = 1, 60 do
			Simulation.step(s)
		end
		expect(countOf(s, "corrisco")).toBe(0)

		local s2 = newMatch({ mapId = "sotao" })
		local boss2 = spawn(s2, "breu", 2)
		boss2.bossNextTelegraphAt = s2.simTime
		for _ = 1, 60 do
			Simulation.step(s2)
			if countOf(s2, "corrisco") == 4 then
				break
			end
		end
		expect(countOf(s2, "corrisco")).toBe(4)
		boss2.hp = 0
		Simulation.step(s2)
		expect(countOf(s2, "corrisco")).toBe(4)
	end)

	it("a onda não termina enquanto houver invocados vivos", function()
		local s = newMatch({ mapId = "sotao" })
		s.phase = "Wave"
		s.waveIndex = 1
		s.waveRuntime.allGroupsSpawned = true
		local boss = spawn(s, "breu", 2)
		boss.bossNextTelegraphAt = s.simTime
		for _ = 1, 60 do
			Simulation.step(s)
			if countOf(s, "corrisco") == 4 then
				break
			end
		end
		boss.hp = 0
		Simulation.step(s)
		expect(s.phase).toBe("Wave")
		expect(countOf(s, "corrisco")).toBe(4)
	end)
end)

describe("Guia / apresentação e rede", function()
	it("snapshot leva prazo do aviso, armadura atual e resistência", function()
		local s = newMatch({ mapId = "oficina" })
		local boss = spawn(s, "rei_ferrugem", 1)
		spawn(s, "nevoa", 1)
		boss.bossNextTelegraphAt = s.simTime
		Simulation.step(s)
		local list = Snapshot.enemies(s)
		local bossSnap, nevoaSnap
		for _, e in ipairs(list) do
			if e.d == "rei_ferrugem" then
				bossSnap = e
			elseif e.d == "nevoa" then
				nevoaSnap = e
			end
		end
		expect(bossSnap.tg).toBe(true)
		expect(bossSnap.tga).toBeCloseTo(boss.bossResolveAt, 1e-6)
		expect(bossSnap.ar).toBeCloseTo(0.2)
		expect(nevoaSnap.er).toBeCloseTo(0.35)
		for _ = 1, 41 do
			Simulation.step(s)
		end
		local after = Snapshot.enemies(s)
		for _, e in ipairs(after) do
			if e.d == "rei_ferrugem" then
				expect(e.ab).toBeCloseTo(0.35)
				expect(e.ar).toBeCloseTo(0.55)
				expect(e.tg).toBe(false)
			end
		end
	end)

	it("2x produz o mesmo resultado lógico que 1x no mesmo tempo simulado", function()
		local function runUntilAbility(steps)
			local s = newMatch({ mapId = "sotao" })
			local boss = spawn(s, "breu", 2)
			boss.bossNextTelegraphAt = s.simTime
			for _ = 1, steps do
				Simulation.step(s)
			end
			return s, boss
		end
		-- o multiplicador de velocidade muda quantos passos cabem por segundo real,
		-- não o tamanho do passo: o mesmo número de passos dá o mesmo estado.
		local a = runUntilAbility(60)
		local b = runUntilAbility(60)
		expect(countOf(a, "corrisco")).toBe(countOf(b, "corrisco"))
		expect(a.simTime).toBeCloseTo(b.simTime)
	end)
end)
