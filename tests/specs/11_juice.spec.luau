-- Juice e Skin só existem dentro do Roblox (criam Instances), mas as curvas que definem a
-- sensação são puras e ficam cobertas aqui: é o que garante que "reduzir movimento" e o
-- decaimento do tremor continuem previsíveis depois de qualquer ajuste de estética.
local Enums = load("Shared/Net/Enums")
local UiMotion = load("Shared/Config/UiMotion")

describe("UiMotion / receitas do revamp", function()
	local EXPECTED = {
		juice_pop = 0.22,
		juice_press = 0.07,
		juice_hit = 0.09,
		juice_shake = 0.26,
		juice_float = 0.7,
		juice_burst = 0.42,
		juice_collect = 0.52,
		banner = 0.42,
		card_select = 0.14,
	}

	it("todas as receitas de suco existem com a duração declarada nos dados", function()
		for id, duration in pairs(EXPECTED) do
			local recipe = UiMotion[id]
			expect(recipe).toBeTruthy()
			expect(math.abs(recipe.duration - duration) < 0.0005).toBeTruthy()
		end
	end)

	it("toda receita descreve o que acontece com movimento reduzido", function()
		for id in pairs(EXPECTED) do
			expect(#UiMotion[id].reduced > 0).toBeTruthy()
		end
	end)

	it("nenhum efeito de combate passa de 1 s: a leitura da onda vem antes da festa", function()
		for id in pairs(EXPECTED) do
			expect(UiMotion[id].duration <= 1).toBeTruthy()
		end
	end)
end)

describe("Enums / o fio não cresce com o catálogo", function()
	it("inimigos, torres e eventos cabem em um byte com folga", function()
		expect(Enums.count(Enums.enemy) <= 64).toBeTruthy()
		expect(Enums.count(Enums.tower) <= 32).toBeTruthy()
		expect(Enums.count(Enums.event) <= 64).toBeTruthy()
	end)

	it("id 0 é reservado para ausente", function()
		expect(Enums.toValue(Enums.enemy, 0)).toBeNil()
		expect(Enums.toId(Enums.enemy, nil)).toBe(0)
		expect(Enums.toValueOr(Enums.tower, 0, "dardo")).toBe("dardo")
	end)
end)
