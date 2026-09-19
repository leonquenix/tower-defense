local Stars = load("Shared/Rules/Stars")
local Balance = load("Shared/Config/Balance")

local function stats(over)
	local base = { damageTaken = 0, towersBuilt = 0, towerIds = {}, wavesRushed = 0, wavesTotal = 5 }
	for key, value in pairs(over or {}) do
		base[key] = value
	end
	return base
end

describe("Stars / objetivos", function()
	it("sem vazamento exige dano zero", function()
		expect(Stars.objectiveMet({ kind = "noLeak" }, stats())).toBe(true)
		expect(Stars.objectiveMet({ kind = "noLeak" }, stats({ damageTaken = 1 }))).toBe(false)
	end)
	it("dano máximo aceita o limite e recusa acima", function()
		local objective = { kind = "maxDamage", value = 20 }
		expect(Stars.objectiveMet(objective, stats({ damageTaken = 20 }))).toBe(true)
		expect(Stars.objectiveMet(objective, stats({ damageTaken = 21 }))).toBe(false)
	end)
	it("teto de torres conta as construídas", function()
		local objective = { kind = "maxTowers", value = 3 }
		expect(Stars.objectiveMet(objective, stats({ towersBuilt = 3 }))).toBe(true)
		expect(Stars.objectiveMet(objective, stats({ towersBuilt = 4 }))).toBe(false)
	end)
	it("só estas torres recusa qualquer intrusa e exige ter jogado", function()
		local objective = { kind = "onlyTowers", towers = { "dardo", "goma" } }
		expect(Stars.objectiveMet(objective, stats({ towerIds = { dardo = true } }))).toBe(true)
		expect(Stars.objectiveMet(objective, stats({ towerIds = { dardo = true, voltz = true } }))).toBe(false)
		expect(Stars.objectiveMet(objective, stats())).toBe(false)
	end)
	it("adiantar todas exige uma chamada por onda", function()
		local objective = { kind = "rushAll" }
		expect(Stars.objectiveMet(objective, stats({ wavesRushed = 5 }))).toBe(true)
		expect(Stars.objectiveMet(objective, stats({ wavesRushed = 4 }))).toBe(false)
	end)
	it("objetivo desconhecido nunca vira estrela", function()
		expect(Stars.objectiveMet({ kind = "coisaNova" }, stats())).toBe(false)
	end)
	it("derrota não leva estrela nenhuma, nem a de objetivo cumprido", function()
		local level = Balance.campaign.levels[1]
		local lost = Stars.evaluate(level, false, stats())
		expect(lost.stars).toBe(0)
		expect(lost.earned[1]).toBe(false)
		local won = Stars.evaluate(level, true, stats({ towersBuilt = 2 }))
		expect(won.earned[1]).toBe(true)
		expect(won.stars).toBe(3)
	end)
	it("todas as fases declaram dois objetivos que a regra conhece", function()
		for _, level in ipairs(Balance.campaign.levels) do
			expect(#level.objectives).toBe(2)
			for _, objective in ipairs(level.objectives) do
				local met = Stars.objectiveMet(objective, stats({ wavesTotal = level.waves }))
				expect(typeof(met)).toBe("boolean")
			end
		end
	end)
end)
