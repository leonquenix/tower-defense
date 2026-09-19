local BuildIntent = load("Client/Controllers/BuildIntent")

local function tap(fields)
	local base = { touch = false, guided = false, sameCell = false, valid = true }
	for key, value in pairs(fields) do
		base[key] = value
	end
	return base
end

describe("BuildIntent / o que o toque significa", function()
	it("no computador, um clique em célula boa já constrói", function()
		expect(BuildIntent.decide(tap({}))).toBe("place")
	end)

	it("no toque, o primeiro toque posiciona e o segundo constrói", function()
		expect(BuildIntent.decide(tap({ touch = true }))).toBe("position")
		expect(BuildIntent.decide(tap({ touch = true, sameCell = true }))).toBe("place")
	end)

	it("célula inválida nunca constrói, em nenhum aparelho", function()
		expect(BuildIntent.decide(tap({ valid = false }))).toBe("blocked")
		expect(BuildIntent.decide(tap({ valid = false, touch = true, sameCell = true }))).toBe("blocked")
		expect(BuildIntent.decide(tap({ valid = false, guided = true }))).toBe("blocked")
	end)

	it("no tutorial a célula é uma só: o primeiro toque constrói mesmo no celular", function()
		expect(BuildIntent.decide(tap({ guided = true, touch = true }))).toBe("place")
	end)
end)
