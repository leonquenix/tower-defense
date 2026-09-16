local Combat = load("Shared/Rules/Combat")
local Circuits = load("Shared/Rules/Circuits")
local Rewards = load("Shared/Rules/Rewards")
local Balance = load("Shared/Config/Balance")
local Catalog = load("Shared/Config/Catalog")

local effects = Balance.effects

local function enemy(id, overrides)
	local e = {
		id = id,
		defId = "fiapo",
		isBoss = false,
		isSummon = false,
		hp = 100,
		maxHp = 100,
		s = 0,
		baseSpeed = 1,
		armor = 0,
		energyResistance = 0,
		bounty = 8,
		leak = 2,
		alive = true,
		spawnedAt = 0,
		slows = {},
		marks = {},
		lastHealAt = 0,
		bossArmorBonus = 0,
		bossArmorUntil = 0,
		bossNextTelegraphAt = math.huge,
		bossTelegraphing = false,
		bossResolveAt = 0,
		bossTargetCell = nil,
	}
	for k, v in pairs(overrides or {}) do
		e[k] = v
	end
	return e
end

local function tower(id, defId, x, y, state)
	return {
		id = id,
		ownerUserId = 1,
		defId = defId,
		state = state or "L0",
		x = x,
		y = y,
		cooldown = 0,
		targetMode = "first",
		invested = 0,
		placedAt = 0,
		circuitPartnerId = nil,
		circuitId = nil,
		dustUntil = 0,
		attackSeq = 0,
		activeSeconds = 0,
	}
end

describe("Combat / fórmula de dano", function()
	it("T07: Dardo L3B ignora integralmente a armadura de Latinha", function()
		local dmg = Combat.computeDamage({
			baseDamage = 42,
			damageType = "physical",
			armorIgnore = 1,
			mark = 0,
			armor = 0.45,
			energyResistance = 0,
			isBoss = false,
			armorCap = 0.8,
		})
		expect(dmg).toBeCloseTo(42)
	end)
	it("armadura reduz dano físico e respeita o limite de 0,80", function()
		local dmg = Combat.computeDamage({
			baseDamage = 100,
			damageType = "physical",
			mark = 0,
			armor = 0.45,
			energyResistance = 0,
			isBoss = false,
			armorCap = 0.8,
		})
		expect(dmg).toBeCloseTo(55)
		local capped = Combat.computeDamage({
			baseDamage = 100,
			damageType = "physical",
			mark = 0,
			armor = 0.95,
			energyResistance = 0,
			isBoss = false,
			armorCap = 0.8,
		})
		expect(capped).toBeCloseTo(20)
	end)
	it("Demolidora ignora metade da armadura", function()
		local dmg = Combat.computeDamage({
			baseDamage = 115,
			damageType = "physical",
			armorIgnore = 0.5,
			mark = 0,
			armor = 0.45,
			energyResistance = 0,
			isBoss = false,
			armorCap = 0.8,
		})
		expect(dmg).toBeCloseTo(115 * (1 - 0.225))
	end)
	it("energia ignora armadura e sofre resistência de energia", function()
		local dmg = Combat.computeDamage({
			baseDamage = 20,
			damageType = "energy",
			mark = 0,
			armor = 0.45,
			energyResistance = 0.35,
			isBoss = false,
			armorCap = 0.8,
		})
		expect(dmg).toBeCloseTo(13)
	end)
	it("bônus contra chefe só vale para chefes e multiplica com Circuito e marca", function()
		local normal = Combat.computeDamage({
			baseDamage = 280,
			damageType = "physical",
			bossBonus = 0.25,
			mark = 0,
			armor = 0,
			energyResistance = 0,
			isBoss = false,
			armorCap = 0.8,
		})
		expect(normal).toBeCloseTo(280)
		local boss = Combat.computeDamage({
			baseDamage = 280,
			damageType = "physical",
			bossBonus = 0.25,
			circuitBonus = 0.15,
			mark = 0.1,
			armor = 0.15,
			energyResistance = 0,
			isBoss = true,
			armorCap = 0.8,
		})
		expect(boss).toBeCloseTo(280 * 1.25 * 1.15 * 1.1 * 0.85)
	end)
end)

describe("Combat / efeitos", function()
	it("T08: lentidões não se somam; vale a maior ativa", function()
		local e = enemy(1)
		Combat.applyEffect(e.slows, 0.2, 1.5, 10, 0)
		Combat.applyEffect(e.slows, 0.3, 3, 0, 0)
		expect(Combat.activeSlow(e, 0.5, effects)).toBeCloseTo(0.3)
		expect(Combat.activeSlow(e, 2.9, effects)).toBeCloseTo(0.3)
		expect(Combat.activeSlow(e, 3.1, effects)).toBeCloseTo(0)
	end)
	it("T09: Supercola (45%) em chefe reduz velocidade em 15,75%", function()
		local boss = enemy(2, { isBoss = true })
		Combat.applyEffect(boss.slows, 0.45, 2.5, 7, 0)
		expect(Combat.activeSlow(boss, 1, effects)).toBeCloseTo(0.1575)
	end)
	it("lentidão é limitada a 50%", function()
		local e = enemy(3)
		Combat.applyEffect(e.slows, 0.9, 2, 7, 0)
		expect(Combat.activeSlow(e, 1, effects)).toBeCloseTo(0.5)
	end)
	it("marcas não se somam e renovam duração", function()
		local e = enemy(4)
		Combat.applyEffect(e.marks, 0.1, 3, 5, 0)
		Combat.applyEffect(e.marks, 0.1, 3, 5, 2)
		expect(Combat.activeMark(e, 4.5)).toBeCloseTo(0.1)
		expect(#e.marks).toBe(1)
		expect(Combat.activeMark(e, 5.1)).toBe(0)
	end)
	it("T10: dois Maestros de 12% e 25% cobrem Dardo -> intervalo dividido por 1,25", function()
		local dardo = tower(1, "dardo", 5, 5)
		local m1 = tower(2, "maestro", 6, 5, "L1")
		local m2 = tower(3, "maestro", 5, 6, "L3B")
		local getHaste = function(t)
			local s = Catalog.getStateStats(t.defId, t.state)
			return s and s.haste
		end
		local getRange = function(t)
			return Catalog.getStateStats(t.defId, t.state).range
		end
		local haste = Combat.hasteFor(dardo, { dardo, m1, m2 }, getHaste, getRange)
		expect(haste).toBeCloseTo(0.25)
		expect(Combat.effectiveInterval(0.8, haste, false, 0.75)).toBeCloseTo(0.8 / 1.25)
		-- Maestro não acelera Maestro
		expect(Combat.hasteFor(m1, { dardo, m1, m2 }, getHaste, getRange)).toBe(0)
	end)
	it("poeira do Aspirador divide por 0,75 depois da aura", function()
		expect(Combat.effectiveInterval(0.8, 0.25, true, 0.75)).toBeCloseTo(0.8 / 1.25 / 0.75)
	end)
	it("upgrade preserva a fração de cooldown", function()
		expect(Combat.carryCooldown(0.4, 0.8, 0.75)).toBeCloseTo(0.375)
		expect(Combat.carryCooldown(0, 0.8, 0.75)).toBe(0)
	end)
end)

describe("Combat / alvos", function()
	local t = tower(1, "dardo", 5, 5)
	local a = enemy(1, { s = 3, hp = 50 })
	local b = enemy(2, { s = 7, hp = 90 })
	local c = enemy(3, { s = 7, hp = 90 })
	local far = enemy(4, { s = 20, hp = 999 })
	local cands = {
		{ enemy = a, px = 5, py = 6 },
		{ enemy = b, px = 6, py = 5 },
		{ enemy = c, px = 7, py = 5 },
		{ enemy = far, px = 15, py = 9 },
	}
	it("First escolhe maior s, empate pelo menor ID", function()
		expect(Combat.selectTarget(t, 2.5, cands, "first").enemy.id).toBe(2)
	end)
	it("Last escolhe menor s", function()
		expect(Combat.selectTarget(t, 2.5, cands, "last").enemy.id).toBe(1)
	end)
	it("Strongest escolhe maior vida, empate pelo menor ID", function()
		expect(Combat.selectTarget(t, 2.5, cands, "strongest").enemy.id).toBe(2)
	end)
	it("Closest escolhe menor distância", function()
		expect(Combat.selectTarget(t, 2.5, cands, "closest").enemy.id).toBe(1)
	end)
	it("alcance inclui igualdade", function()
		local exact = { { enemy = enemy(9, { s = 1 }), px = 7.5, py = 5 } }
		expect(Combat.selectTarget(t, 2.5, exact, "first")).toBeTruthy()
		expect(Combat.selectTarget(t, 2.49, exact, "first")).toBeNil()
	end)
	it("explosão inclui primário e mais próximos até maxTargets", function()
		local targets = Combat.splashTargets(cands[2], cands, 1, 2)
		expect(#targets).toBe(2)
		expect(targets[1].enemy.id).toBe(2)
		expect(targets[2].enemy.id).toBe(3)
	end)
	it("T13: Voltz L0 acerta dois alvos: 20 e 15", function()
		local chain = Combat.chainTargets(cands[2], cands, 2, 1.5)
		expect(#chain).toBe(2)
		local d0 = 20 * 0.75 ^ 0
		local d1 = 20 * 0.75 ^ 1
		expect(d0).toBe(20)
		expect(d1).toBe(15)
	end)
	it("corrente nunca repete entidade e respeita chainRadius", function()
		local chain = Combat.chainTargets(cands[1], cands, 5, 1.5)
		local seen = {}
		for _, c in ipairs(chain) do
			expect(seen[c.enemy.id]).toBeNil()
			seen[c.enemy.id] = true
		end
		expect(#chain).toBe(3)
	end)
end)

describe("Circuits", function()
	local lookup = Catalog.getCircuitFor
	it("pareia Dardo e Goma ortogonalmente adjacentes", function()
		local d = tower(1, "dardo", 3, 3)
		local g = tower(2, "goma", 3, 4)
		local a = Circuits.assign({ d, g }, lookup)
		expect(a[1].partnerId).toBe(2)
		expect(a[2].partnerId).toBe(1)
		expect(a[1].circuitId).toBe("pega_e_acerta")
	end)
	it("diagonal não conta", function()
		local a = Circuits.assign({ tower(1, "dardo", 3, 3), tower(2, "goma", 4, 4) }, lookup)
		expect(a[1]).toBeNil()
	end)
	it("pares incompatíveis não conectam", function()
		local a = Circuits.assign({ tower(1, "dardo", 3, 3), tower(2, "pipoca", 3, 4) }, lookup)
		expect(a[1]).toBeNil()
	end)
	it("T11: três torres disputam um Circuito -> pares determinísticos por ID, sem dupla conexão", function()
		local goma = tower(5, "goma", 3, 3)
		local dardoA = tower(7, "dardo", 3, 4)
		local dardoB = tower(6, "dardo", 4, 3)
		local a = Circuits.assign({ dardoA, goma, dardoB }, lookup)
		expect(a[5].partnerId).toBe(6)
		expect(a[6].partnerId).toBe(5)
		expect(a[7]).toBeNil()
	end)
	it("ordem por menor ID e depois maior ID", function()
		-- (1,4) vence (1,9) para a torre 1; torre 9 fica com 3 se adjacente
		local t1 = tower(1, "dardo", 5, 5)
		local t4 = tower(4, "goma", 5, 6)
		local t9 = tower(9, "goma", 6, 5)
		local t3 = tower(3, "dardo", 7, 5)
		local a = Circuits.assign({ t9, t3, t1, t4 }, lookup)
		expect(a[1].partnerId).toBe(4)
		expect(a[3].partnerId).toBe(9)
	end)
	it("prévia mostra o par que seria ativado", function()
		local existing = { tower(1, "goma", 3, 3) }
		local hyp = tower(2, "dardo", 3, 4)
		local p = Circuits.preview(existing, hyp, lookup)
		expect(p.partnerId).toBe(1)
	end)
end)

describe("Rewards", function()
	it("T20: bounty 10 com três participantes -> 4,3,3 com cursor giratório", function()
		local order = { 100, 200, 300 }
		local r = Rewards.splitBounty(10, order, 1)
		expect(r.shares[100]).toBe(4)
		expect(r.shares[200]).toBe(3)
		expect(r.shares[300]).toBe(3)
		expect(r.cursor).toBe(2)
		local r2 = Rewards.splitBounty(10, order, r.cursor)
		expect(r2.shares[200]).toBe(4)
		expect(r2.cursor).toBe(3)
		local r3 = Rewards.splitBounty(8, order, r2.cursor)
		expect(r3.shares[300]).toBe(3)
		expect(r3.shares[100]).toBe(3)
		expect(r3.shares[200]).toBe(2)
		expect(r3.cursor).toBe(2)
	end)
	it("venda devolve 70% arredondado para baixo (T06: 450 -> 315)", function()
		expect(Rewards.sellRefund(450, 0.7)).toBe(315)
		expect(Rewards.sellRefund(255, 0.7)).toBe(178)
	end)
	it("botões por resultado", function()
		expect(Rewards.buttonsForOutcome("normal", "won", 20, Balance.difficulties.normal, Balance.rewards)).toBe(120)
		expect(Rewards.buttonsForOutcome("normal", "won", 20, Balance.difficulties.desafio, Balance.rewards)).toBe(160)
		expect(Rewards.buttonsForOutcome("normal", "lost", 7, Balance.difficulties.normal, Balance.rewards)).toBe(28)
		expect(Rewards.buttonsForOutcome("normal", "lost", 19, Balance.difficulties.normal, Balance.rewards)).toBe(60)
		expect(Rewards.buttonsForOutcome("tutorial", "won", 3, Balance.difficulties.normal, Balance.rewards)).toBe(180)
		expect(Rewards.buttonsForOutcome("training", "won", 3, Balance.difficulties.normal, Balance.rewards)).toBe(0)
	end)
	it("domínio exige 30 s colocada e cinco ondas em derrota", function()
		expect(Rewards.masteryPoints("normal", "won", 20, 31, Balance.rewards)).toBe(10)
		expect(Rewards.masteryPoints("normal", "won", 20, 10, Balance.rewards)).toBe(0)
		expect(Rewards.masteryPoints("normal", "lost", 5, 40, Balance.rewards)).toBe(4)
		expect(Rewards.masteryPoints("normal", "lost", 4, 40, Balance.rewards)).toBe(0)
		expect(Rewards.masteryPoints("tutorial", "won", 3, 40, Balance.rewards)).toBe(0)
	end)
	it("marcos de domínio", function()
		expect(Rewards.newMilestones(25, 35, Balance.rewards.masteryMilestones)).toEqual({ 30 })
		expect(Rewards.newMilestones(0, 300, Balance.rewards.masteryMilestones)).toEqual({ 30, 100, 250 })
		expect(Rewards.newMilestones(30, 40, Balance.rewards.masteryMilestones)).toEqual({})
	end)
end)
