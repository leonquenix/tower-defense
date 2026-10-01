-- Encomenda de arte v2: torres, inimigos, chefes, mapas e fases novas.
-- Cobre o que a simulação decide (servidor): duração, acúmulo, renovação, limites, imunidades,
-- prioridade e interação dos efeitos, e o cancelamento das habilidades de chefe.
local Simulation = load("Shared/Sim/Simulation")
local Snapshot = load("Shared/Sim/Snapshot")
local Balance = load("Shared/Config/Balance")
local Catalog = load("Shared/Config/Catalog")
local Combat = load("Shared/Rules/Combat")
local Codec = load("Shared/Net/Codec")
local ProfileSchema = load("Shared/Profile/ProfileSchema")

local USER = 100

local function newMatch(opts)
	opts = opts or {}
	local parts = {}
	for i = 1, (opts.players or 1) do
		table.insert(parts, {
			userId = USER * i,
			connected = true,
			active = true,
			ready = false,
			speedVote = 1,
			loadout = { "dardo", "pipoca", "goma" },
			displayName = "P" .. i,
		})
	end
	local state = Simulation.new({
		matchId = "m-v2",
		configVersion = "test",
		mode = opts.mode or "normal",
		mapId = opts.mapId or "oficina",
		difficulty = "normal",
		participants = parts,
		seed = 1,
		trainingUnlockAll = true,
		retryAllowed = opts.retryAllowed,
	})
	for _, p in ipairs(parts) do
		state.wallets[p.userId] = 1e6
	end
	state.phase = "Wave"
	state.waveRuntime.nextSpawnAt = math.huge
	return state
end

-- Inimigo parado (velocidade 0) num ponto do caminho: a Oficina corre em y=2 de x=0 a x=13.
local function spawn(state, defId, s, opts)
	opts = opts or {}
	local mode = state.mode
	state.mode = "training"
	Simulation.trainingSpawn(state, defId, 1)
	Simulation.step(state)
	state.mode = mode
	state.phase = "Wave"
	local e = state.enemies[state.enemyOrder[#state.enemyOrder]]
	e.s = s
	e.baseSpeed = opts.speed or 0
	if opts.hp then
		e.hp = opts.hp
		e.maxHp = opts.hp
	end
	return e
end

local function place(state, towerId, x, y, towerState, userId)
	local result = Simulation.placeTower(state, userId or USER, towerId, x, y)
	assert(result.ok, "não colocou " .. towerId .. ": " .. tostring(result.errorCode))
	local tower = state.towers[result.entityId]
	if towerState then
		tower.state = towerState
	end
	return tower
end

local function stepUntil(state, predicate, maxSteps)
	for _ = 1, maxSteps or 200 do
		local events = Simulation.step(state)
		for _, e in ipairs(events) do
			if predicate(e) then
				return e
			end
		end
	end
	return nil
end

local function attackOf(towerId)
	return function(e)
		return e.kind == "attack" and e.towerId == towerId
	end
end

local function physical(enemy, amount, simTime)
	return Combat.computeDamage({
		baseDamage = amount,
		damageType = "physical",
		mark = 0,
		armor = Combat.currentArmor(enemy, simTime, Balance.effects.shredCap),
		energyResistance = enemy.energyResistance,
		isBoss = enemy.isBoss,
		armorCap = Balance.effects.physicalArmorCap,
	})
end

describe("Encomenda v2 / catálogo", function()
	it("seis torres novas com cinco estados, dois ramos e o nível de desbloqueio da encomenda", function()
		local levels = { escova = 4, lumi = 5, pula = 7, piao = 11, picole = 13, fofo = 15 }
		for id, level in pairs(levels) do
			local def = Catalog.getTower(id)
			expect(def ~= nil).toBe(true)
			expect(def.unlockLevel).toBe(level)
			expect(#def.branchNames).toBe(2)
			for _, st in ipairs({ "L0", "L1", "L2", "L3A", "L3B" }) do
				expect(def.states[st] ~= nil).toBe(true)
			end
		end
		expect(#Balance.towers).toBe(12)
		expect(Catalog.getTower("fofo").damageType).toBe("none")
	end)

	it("rotas dos mapas novos, comprimento e chefe de cada um", function()
		local want = {
			oficina = { cells = 44, boss = "rei_ferrugem", last = { 15, 8 } },
			inverno = { cells = 25, boss = "boneco_poeira", last = { 15, 7 } },
			cozinha = { cells = 24, boss = "esponjao", last = { 15, 5 } },
			quarto = { cells = 41, boss = "meia", last = { 15, 7 } },
			porao = { cells = 50, boss = "traca_rainha", last = { 15, 7 } },
		}
		for id, w in pairs(want) do
			local map = Catalog.getMap(id)
			expect(#map.pathCells).toBe(w.cells)
			expect(map.boss).toBe(w.boss)
			expect(map.path[#map.path]).toEqual(w.last)
			expect(map.path[1][1]).toBe(0)
		end
	end)

	it("campanha segue a casa: Jardim, Oficina, Inverno, Cozinha, Quarto, Sótão, Porão", function()
		local order = {}
		for _, level in ipairs(Catalog.levels()) do
			if order[#order] ~= level.mapId then
				table.insert(order, level.mapId)
			end
		end
		expect(order).toEqual({ "jardim", "oficina", "inverno", "cozinha", "quarto", "sotao", "porao" })
		expect(#Catalog.levels()).toBe(24)
	end)

	it("grupos do mapa entram só no mapa certo e a partir da onda indicada", function()
		local function count(mapId, wave, enemy)
			local n = 0
			for _, g in ipairs(Simulation.waveFor(mapId, wave).groups) do
				if g.enemy == enemy then
					n += g.count
				end
			end
			return n
		end
		expect(count("cozinha", 1, "migalha")).toBe(0)
		expect(count("cozinha", 2, "migalha")).toBe(6)
		expect(count("cozinha", 12, "migalha")).toBe(9) -- 6 + floor(0,3 x 10)
		expect(count("jardim", 12, "migalha")).toBe(0)
		expect(count("inverno", 3, "floquinho")).toBe(3)
		expect(count("porao", 8, "novelo")).toBe(2)
		-- a tabela global não é alterada pelo acréscimo
		expect(#Simulation.waveFor("jardim", 12).groups).toBe(#Balance.waves[12].groups)
	end)
end)

describe("Escovinha / armadura raspada", function()
	it("raspa, renova pela mesma torre e some ao fim da duração", function()
		local s = newMatch()
		local e = spawn(s, "latinha", 3)
		local t = place(s, "escova", 3, 3)
		stepUntil(s, attackOf(t.id))
		expect(Combat.currentArmor(e, s.simTime, Balance.effects.shredCap)).toBeCloseTo(0.35)
		-- dano físico sobe porque a armadura caiu
		expect(physical(e, 20, s.simTime)).toBeGreaterThan(11)
		-- a mesma torre não acumula no L0: segue em 0,10
		stepUntil(s, attackOf(t.id))
		expect(Combat.activeShred(e, s.simTime, Balance.effects.shredCap)).toBeCloseTo(0.1)
		-- vendida a torre, a raspagem acaba sozinha depois da duração
		Simulation.sellTower(s, USER, t.id)
		for _ = 1, 70 do
			Simulation.step(s)
		end
		expect(Combat.currentArmor(e, s.simTime, Balance.effects.shredCap)).toBeCloseTo(0.45)
	end)

	it("Escova de Aço acumula até quatro raspadas e o total respeita shredCap", function()
		local s = newMatch()
		local e = spawn(s, "latinha", 3, { hp = 1e6 })
		local t = place(s, "escova", 3, 3, "L3B")
		for _ = 1, 6 do
			stepUntil(s, attackOf(t.id))
		end
		expect(Combat.activeShred(e, s.simTime, Balance.effects.shredCap)).toBeCloseTo(0.48)
		Combat.applyShred(e.shreds, 0.3, 4, 999, s.simTime, 1)
		-- fontes diferentes não somam: vale a maior, e nunca passa do teto
		expect(Combat.activeShred(e, s.simTime, Balance.effects.shredCap)).toBeCloseTo(0.48)
		Combat.applyShred(e.shreds, 0.6, 4, 998, s.simTime, 1)
		expect(Combat.activeShred(e, s.simTime, Balance.effects.shredCap)).toBeCloseTo(Balance.effects.shredCap)
		expect(Combat.currentArmor(e, s.simTime, Balance.effects.shredCap)).toBe(0)
	end)

	it("raspa o Rei Ferrugem por cima do reforço de armadura", function()
		local s = newMatch()
		local boss = spawn(s, "rei_ferrugem", 3, { hp = 1e6 })
		boss.bossArmorBonus = 0.35
		boss.bossArmorUntil = math.huge
		local t = place(s, "escova", 3, 3, "L2")
		stepUntil(s, attackOf(t.id))
		expect(Combat.currentArmor(boss, s.simTime, Balance.effects.shredCap)).toBeCloseTo(0.2 + 0.35 - 0.18)
	end)
end)

describe("Lumi / queimadura e bloqueio de cura", function()
	it("queima pelo tempo da duração, credita o dono e não soma com outra Lumi", function()
		local s = newMatch()
		local e = spawn(s, "bolota", 3, { hp = 1e6 })
		local t = place(s, "lumi", 3, 3)
		stepUntil(s, attackOf(t.id))
		local hit = Balance.towers[8].states.L0.damage
		local after = e.hp
		expect(Combat.activeBurn(e, s.simTime).strength).toBe(6)
		-- segunda Lumi mais fraca não soma: a mais forte manda
		Combat.applyBurn(e.burns, 3, 3, 777, USER, s.simTime)
		expect(Combat.activeBurn(e, s.simTime).strength).toBe(6)
		Simulation.sellTower(s, USER, t.id)
		local before = s.stats[USER].damage
		for _ = 1, 80 do
			Simulation.step(s)
		end
		-- 6 por segundo durante o resto dos 3 s (a outra entrada, de 3/s, some junto)
		expect(e.hp).toBeLessThan(after)
		expect(s.stats[USER].damage).toBeGreaterThan(before)
		expect(Combat.activeBurn(e, s.simTime)).toBeNil()
		expect(hit).toBe(6)
	end)

	it("inimigo queimando não recebe a cura do Remendo", function()
		local s = newMatch()
		local hurt = spawn(s, "bolota", 3, { hp = 100 })
		hurt.hp = 50
		local healer = spawn(s, "remendo", 3.5)
		healer.lastHealAt = -100
		Combat.applyBurn(hurt.burns, 0.0001, 10, 555, USER, s.simTime)
		Simulation.step(s)
		expect(hurt.hp).toBeLessThan(50.01)
		-- sem queimadura, a cura volta
		hurt.burns = {}
		healer.lastHealAt = -100
		Simulation.step(s)
		expect(hurt.hp).toBeGreaterThan(55)
	end)

	it("Holofote esquenta no mesmo alvo e zera ao trocar", function()
		local s = newMatch()
		local a = spawn(s, "bolota", 3, { hp = 1e6 })
		local t = place(s, "lumi", 3, 3, "L3A")
		local first = stepUntil(s, attackOf(t.id)).targets[1].damage
		local second = stepUntil(s, attackOf(t.id)).targets[1].damage
		expect(second).toBeCloseTo(first * 1.15)
		expect(t.focusStacks).toBe(1)
		-- outro alvo mais adiantado vira o primeiro: o feixe recomeça
		spawn(s, "bolota", 4, { hp = 1e6 })
		local third = stepUntil(s, attackOf(t.id))
		expect(third.targets[1].enemyId ~= a.id).toBe(true)
		expect(t.focusStacks).toBe(0)
	end)

	it("Enxame acende os vizinhos do alvo sem gastar a esquiva da Traça", function()
		local s = newMatch()
		local main = spawn(s, "bolota", 3, { hp = 1e6 })
		local near = spawn(s, "traca", 2.2, { hp = 1e6 })
		local t = place(s, "lumi", 3, 3, "L3B")
		stepUntil(s, attackOf(t.id))
		expect(Combat.activeBurn(main, s.simTime) ~= nil).toBe(true)
		expect(Combat.activeBurn(near, s.simTime) ~= nil).toBe(true)
		expect(near.dodgeReadyAt).toBeLessThan(s.simTime + 0.01)
	end)
end)

describe("Pula / empurrão", function()
	it("empurra para trás no caminho, com recarga, teto e sem sair da rota", function()
		local s = newMatch()
		local e = spawn(s, "bolota", 3, { hp = 1e6 })
		local t = place(s, "pula", 3, 3)
		local ev = stepUntil(s, attackOf(t.id))
		expect(ev.targets[1].flag).toBe(3)
		expect(e.s).toBeCloseTo(2)
		-- recarga: um segundo empurrão logo em seguida não anda
		expect(Combat.pushDistance(e, 1, s.simTime, Balance.effects)).toBe(0)
		-- teto da vida
		e.pushReadyAt = 0
		e.pushedTotal = Balance.effects.maxPushPerEnemy - 0.25
		expect(Combat.pushDistance(e, 1, s.simTime, Balance.effects)).toBeCloseTo(0.25)
		-- nunca antes do começo do caminho
		e.pushedTotal = 0
		e.s = 0.4
		expect(Combat.pushDistance(e, 1, s.simTime, Balance.effects)).toBeCloseTo(0.4)
	end)

	it("chefe resiste: só bossPushFactor do empurrão", function()
		local s = newMatch()
		local boss = spawn(s, "aspirador", 3, { hp = 1e6 })
		local t = place(s, "pula", 3, 3)
		stepUntil(s, attackOf(t.id))
		expect(boss.s).toBeCloseTo(3 - 1 * Balance.effects.bossPushFactor)
	end)

	it("Língua de Sogra puxa o inimigo comum mais forte, nunca o chefe", function()
		local s = newMatch()
		spawn(s, "fiapo", 5)
		local strong = spawn(s, "brutamontes", 2.5, { hp = 5000 })
		spawn(s, "aspirador", 4, { hp = 1e6 })
		local t = place(s, "pula", 3, 3, "L3B")
		local ev = stepUntil(s, attackOf(t.id))
		expect(ev.targets[1].enemyId).toBe(strong.id)
		expect(strong.s).toBeCloseTo(0)
	end)
end)

describe("Pião / todos no alcance", function()
	it("acerta todo inimigo elegível no alcance e nenhum fora dele", function()
		local s = newMatch()
		spawn(s, "fiapo", 2, { hp = 1e6 })
		spawn(s, "fiapo", 3, { hp = 1e6 })
		spawn(s, "fiapo", 4, { hp = 1e6 })
		spawn(s, "fiapo", 9, { hp = 1e6 })
		local t = place(s, "piao", 3, 3)
		local ev = stepUntil(s, attackOf(t.id))
		expect(#ev.targets).toBe(3)
	end)
end)

describe("Picolé / congelamento", function()
	it("congela, solta no tempo certo e respeita a imunidade (a partida não trava)", function()
		local s = newMatch()
		local e = spawn(s, "bolota", 3, { hp = 1e6, speed = 1 })
		local t = place(s, "picole", 3, 3)
		stepUntil(s, attackOf(t.id))
		expect(Combat.isFrozen(e, s.simTime)).toBe(true)
		local frozenAt = e.s
		Simulation.step(s)
		expect(e.s).toBe(frozenAt)
		-- depois de 0,9 s anda de novo e, na imunidade, um novo sopro não congela
		for _ = 1, 20 do
			Simulation.step(s)
		end
		expect(Combat.isFrozen(e, s.simTime)).toBe(false)
		expect(e.s).toBeGreaterThan(frozenAt)
		t.cooldown = 0
		e.s = 3
		stepUntil(s, attackOf(t.id))
		expect(Combat.isFrozen(e, s.simTime)).toBe(false)
	end)

	it("chefe não congela: fica só lento, com a redução de chefe", function()
		local s = newMatch()
		local boss = spawn(s, "rei_ferrugem", 3, { hp = 1e6 })
		local t = place(s, "picole", 3, 3)
		stepUntil(s, attackOf(t.id))
		expect(Combat.isFrozen(boss, s.simTime)).toBe(false)
		expect(Combat.activeSlow(boss, s.simTime, Balance.effects)).toBeCloseTo(
			Balance.effects.frozenBossSlow * Balance.effects.bossSlowStrength
		)
	end)

	it("Geladeira: congelado leva dano extra de qualquer torre", function()
		local s = newMatch()
		local e = spawn(s, "bolota", 3, { hp = 1e6 })
		local ice = place(s, "picole", 3, 3, "L3B")
		stepUntil(s, attackOf(ice.id))
		expect(e.freezeBonus).toBeCloseTo(0.25)
		local dart = place(s, "dardo", 4, 3)
		local ev = stepUntil(s, attackOf(dart.id))
		expect(ev.targets[1].damage).toBeCloseTo(10 * 1.25)
	end)

	it("Novelo: a lentidão da Goma não pega, o congelamento pega", function()
		local s = newMatch()
		local e = spawn(s, "novelo", 3, { hp = 1e6 })
		local goma = place(s, "goma", 3, 3)
		stepUntil(s, attackOf(goma.id))
		expect(#e.slows).toBe(0)
		local ice = place(s, "picole", 4, 3)
		stepUntil(s, attackOf(ice.id))
		expect(Combat.isFrozen(e, s.simTime)).toBe(true)
	end)
end)

describe("Fofo / aura de dano e cura do Farol", function()
	it("aumenta o dano vizinho; dois Fofos valem o maior; Fofo desligado não ajuda", function()
		local s = newMatch()
		spawn(s, "bolota", 3, { hp = 1e6 })
		local dart = place(s, "dardo", 3, 3)
		local bear = place(s, "fofo", 3, 4)
		expect(Simulation.towerBoost(s, dart)).toBeCloseTo(0.08)
		place(s, "fofo", 4, 3, "L3A")
		expect(Simulation.towerBoost(s, dart)).toBeCloseTo(0.22)
		local ev = stepUntil(s, attackOf(dart.id))
		expect(ev.targets[1].damage).toBeCloseTo(10 * 1.22)
		for _, id in ipairs(s.towerOrder) do
			if s.towers[id].defId == "fofo" then
				s.towers[id].disabledUntil = math.huge
			end
		end
		expect(Simulation.towerBoost(s, dart)).toBe(0)
		expect(bear.id > 0).toBe(true)
	end)

	it("Coração Remendado devolve vida ao Farol no fim da onda, com teto e sem passar do máximo", function()
		-- limite de dois Fofos por jogador: o terceiro é do parceiro
		local s = newMatch({ players = 2 })
		place(s, "fofo", 3, 3, "L3B")
		place(s, "fofo", 4, 3, "L3B")
		place(s, "fofo", 5, 3, "L3B", USER * 2)
		s.baseHP = 90
		s.waveIndex = 1
		s.totalWaves = 5
		s.waveRuntime.allGroupsSpawned = true
		local events = Simulation.step(s)
		local healed = 0
		for _, e in ipairs(events) do
			if e.kind == "baseHeal" then
				healed = e.amount
			end
		end
		-- três Fofos x 2 = 6, mas o teto por onda é 4
		expect(healed).toBe(Balance.effects.baseHealPerWaveCap)
		expect(s.baseHP).toBe(94)
		s.baseHP = Balance.baseHP - 1
		s.phase = "Wave"
		s.waveRuntime.allGroupsSpawned = true
		Simulation.step(s)
		expect(s.baseHP).toBe(Balance.baseHP)
		-- dano levado continua contando para a estrela
		expect(s.campaignStats.damageTaken).toBe(0)
	end)
end)

describe("Traça / esquiva", function()
	it("erra o primeiro acerto, leva o seguinte e volta a esquivar depois de 3 s", function()
		local s = newMatch()
		local e = spawn(s, "traca", 3, { hp = 1e6 })
		local dart = place(s, "dardo", 3, 3)
		local first = stepUntil(s, attackOf(dart.id))
		expect(first.targets[1].flag).toBe(1)
		expect(first.targets[1].damage).toBe(0)
		local second = stepUntil(s, attackOf(dart.id))
		expect(second.targets[1].flag).toBeNil()
		expect(second.targets[1].damage).toBeGreaterThan(0)
		-- sem ninguém atirando por 3 s, a esquiva recarrega
		Simulation.sellTower(s, USER, dart.id)
		for _ = 1, 61 do
			Simulation.step(s)
		end
		local again = place(s, "dardo", 3, 3)
		local later = stepUntil(s, attackOf(again.id))
		expect(later.targets[1].flag).toBe(1)
		expect(e.alive).toBe(true)
	end)
end)

describe("Chefes novos", function()
	local function triggerNow(boss, s)
		boss.bossNextTelegraphAt = s.simTime
	end

	it("Boneco de Poeira marca as torres mais caras e congela por 2 s; elas não atiram", function()
		local s = newMatch({ mapId = "inverno" })
		local boss = spawn(s, "boneco_poeira", 5, { hp = 1e6 })
		local cheap = place(s, "dardo", 1, 7)
		local rich = place(s, "lupa", 2, 7, "L2")
		rich.invested = 5000
		local mid = place(s, "pipoca", 5, 7)
		mid.invested = 4000
		triggerNow(boss, s)
		local tele = stepUntil(s, function(e)
			return e.kind == "bossTelegraph"
		end)
		expect(tele.towerIds).toEqual({ rich.id, mid.id })
		local ability = stepUntil(s, function(e)
			return e.kind == "bossAbility"
		end)
		expect(ability.towerIds).toEqual({ rich.id, mid.id })
		expect(rich.disabledReason).toBe("frost")
		expect(Simulation.isDisabled(s, cheap)).toBe(false)
		local before = rich.attackSeq
		for _ = 1, 30 do
			Simulation.step(s)
		end
		expect(rich.attackSeq).toBe(before)
	end)

	it("morte do chefe no meio do aviso cancela a rajada", function()
		local s = newMatch({ mapId = "inverno" })
		local boss = spawn(s, "boneco_poeira", 5, { hp = 1e6 })
		local tower = place(s, "lupa", 2, 7)
		triggerNow(boss, s)
		stepUntil(s, function(e)
			return e.kind == "bossTelegraph"
		end)
		boss.hp = 0
		local cancel = stepUntil(s, function(e)
			return e.kind == "bossCancel"
		end, 5)
		expect(cancel ~= nil).toBe(true)
		for _ = 1, 60 do
			Simulation.step(s)
		end
		expect(tower.disabledUntil).toBe(0)
	end)

	it("Esponjão encharcado absorve energia e se cura; físico passa; queimadura bloqueia a cura", function()
		local s = newMatch({ mapId = "cozinha" })
		local boss = spawn(s, "esponjao", 3, { hp = 10000 })
		boss.bossSoakUntil = math.huge
		boss.hp = 5000
		local volt = place(s, "voltz", 2, 2)
		local ev = stepUntil(s, attackOf(volt.id))
		expect(ev.targets[1].flag).toBe(2)
		expect(boss.hp).toBeGreaterThan(5000)
		local hp = boss.hp
		local dart = place(s, "dardo", 4, 2)
		stepUntil(s, attackOf(dart.id))
		expect(boss.hp).toBeLessThan(hp)
		hp = boss.hp
		Combat.applyBurn(boss.burns, 0.0001, 60, 444, USER, s.simTime)
		volt.cooldown = 0
		stepUntil(s, attackOf(volt.id))
		expect(boss.hp).toBeLessThan(hp + 0.01)
	end)

	it("Meia Sem Par enrola a torre mais próxima; vendida no aviso, nada quebra", function()
		local s = newMatch({ mapId = "quarto" })
		local boss = spawn(s, "meia", 2, { hp = 1e6 })
		local near = place(s, "dardo", 1, 5)
		place(s, "dardo", 12, 9)
		triggerNow(boss, s)
		local tele = stepUntil(s, function(e)
			return e.kind == "bossTelegraph"
		end)
		expect(tele.towerIds).toEqual({ near.id })
		Simulation.sellTower(s, USER, near.id)
		local ability = stepUntil(s, function(e)
			return e.kind == "bossAbility"
		end)
		expect(#(ability.towerIds or {})).toBe(0)
	end)

	it("Traça Rainha esconde um trecho (torres não miram lá) e invoca traças", function()
		local s = newMatch({ mapId = "porao" })
		local boss = spawn(s, "traca_rainha", 10, { hp = 1e6 })
		triggerNow(boss, s)
		local ability = stepUntil(s, function(e)
			return e.kind == "bossAbility"
		end)
		expect(#ability.entityIds).toBe(3)
		expect(#s.pathClouds).toBe(1)
		expect(Simulation.hiddenByCloud(s, 10)).toBe(true)
		-- uma torre ao lado do trecho não acha alvo enquanto a nuvem durar
		local hidden = spawn(s, "fiapo", 10.5, { hp = 1e6 })
		local snap = Snapshot.enemies(s)
		local flagged = false
		for _, e in ipairs(snap) do
			if e.id == hidden.id then
				flagged = bit32.band(e.fx, Snapshot.FX.hidden) ~= 0
			end
		end
		expect(flagged).toBe(true)
		for _ = 1, 45 do
			Simulation.step(s)
		end
		expect(#s.pathClouds).toBe(0)
	end)
end)

describe("Replicação e Retomada", function()
	it("fx, torre desligada e alvo esquivado sobrevivem ao fio", function()
		local s = newMatch()
		local e = spawn(s, "bolota", 3, { hp = 1e6 })
		Combat.applyBurn(e.burns, 5, 3, 1, USER, s.simTime)
		e.freezeUntil = s.simTime + 2
		local t = place(s, "dardo", 3, 3)
		t.disabledUntil = s.simTime + 3
		t.disabledReason = "wrap"
		local snap = Snapshot.build(s, USER, true)
		local back = Codec.decodeSnapshot(Codec.encodeSnapshot(snap))
		expect(back.enemies[1].fx).toBe(Snapshot.FX.burning + Snapshot.FX.frozen)
		expect(back.enemies[1].v).toBe(0)
		expect(back.towers[1].dr).toBe("wrap")
		local wire = Codec.encodeEvent({
			kind = "attack",
			simTime = 1,
			towerId = 1,
			attackSeq = 1,
			targets = { { enemyId = 1, damage = 0, index = 0, flag = 1 } },
		})
		expect(Codec.decodeEvent(wire).targets[1].flag).toBe(1)
		expect(Codec.decodeEvent(Codec.encodeEvent({ kind = "baseHeal", simTime = 1, amount = 2 })).kind).toBe(
			"baseHeal"
		)
	end)

	it("Retomada religa as torres e apaga as nuvens", function()
		local s = newMatch({ mapId = "porao", retryAllowed = true })
		s.phase = "Preparation"
		s.phaseEndsAt = 0
		local t = place(s, "dardo", 1, 2)
		Simulation.step(s) -- foto do início da onda 1
		t = s.towers[t.id]
		t.disabledUntil = math.huge
		table.insert(s.pathClouds, { fromS = 0, toS = 3, expiresAt = math.huge, bossId = 0 })
		s.baseHP = 0
		Simulation.step(s)
		expect(s.phase).toBe("RetryDecision")
		Simulation.applyRetry(s)
		expect(s.towers[t.id].disabledUntil).toBe(0)
		expect(#s.pathClouds).toBe(0)
	end)
end)

describe("Perfil / compatibilidade da campanha reordenada", function()
	it("quem já tinha estrelas no Sótão continua com ele aberto; a fase nova abre pela anterior", function()
		local profile = ProfileSchema.default(0)
		for i = 1, 12 do
			profile.campaign[tostring(i)] = 3
		end
		-- "10" (Sótão) vem depois do Quarto ("21"), que este perfil nunca jogou
		expect(ProfileSchema.campaignUnlocked(profile, "10")).toBe(true)
		expect(ProfileSchema.campaignUnlocked(profile, "13")).toBe(true) -- Inverno abre pela fase 9
		expect(ProfileSchema.campaignUnlocked(profile, "14")).toBe(false)
		expect(ProfileSchema.campaignUnlocked(profile, "22")).toBe(true) -- Porão abre pelo Sótão "12"
		local fresh = ProfileSchema.default(0)
		expect(ProfileSchema.campaignUnlocked(fresh, "10")).toBe(false)
	end)
end)

describe("Controle não trava a partida", function()
	it("onda real com três Picolés e três Pulas no começo do caminho termina", function()
		local s = newMatch()
		s.phase = "Preparation"
		s.phaseEndsAt = 0
		s.totalWaves = 6
		for i, cell in ipairs({ { 1, 3 }, { 3, 3 }, { 5, 1 }, { 2, 1 }, { 4, 3 }, { 7, 1 } }) do
			-- área máxima dos dois: congela e empurra quase todo mundo que passa na entrada
			place(s, if i <= 3 then "picole" else "pula", cell[1], cell[2], "L3A")
		end
		local saw = { freeze = false, push = false }
		local done = false
		s.waveIndex = 5
		s.phase = "Intermission"
		s.phaseEndsAt = 0
		for _ = 1, 20 * 240 do
			local events = Simulation.step(s)
			for _, e in ipairs(events) do
				if e.kind == "attack" then
					for _, t in ipairs(e.targets or {}) do
						if t.flag == 3 then
							saw.push = true
						end
					end
				elseif e.kind == "waveEnd" then
					done = true
				end
			end
			for _, id in ipairs(s.enemyOrder) do
				if Combat.isFrozen(s.enemies[id], s.simTime) then
					saw.freeze = true
				end
			end
			if done or Simulation.isTerminal(s) then
				break
			end
		end
		expect(saw.freeze).toBe(true)
		expect(saw.push).toBe(true)
		expect(done or Simulation.isTerminal(s)).toBe(true)
	end)
end)
