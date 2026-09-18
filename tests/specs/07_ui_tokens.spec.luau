local UiTokens = load("Shared/Config/UiTokens")
local UiMotion = load("Shared/Config/UiMotion")
local UiIcons = load("Shared/Config/UiIcons")
local Localization = load("Shared/Config/Localization")

-- Luminância relativa (WCAG). Mesma fórmula usada por tools/import_ui_tokens.py.
local function luminance(rgb)
	local channels = {}
	for index = 1, 3 do
		local c = rgb[index] / 255
		channels[index] = if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channels[1] + 0.7152 * channels[2] + 0.0722 * channels[3]
end

local function contrast(a, b)
	local la, lb = luminance(a), luminance(b)
	local lighter = math.max(la, lb)
	local darker = math.min(la, lb)
	return (lighter + 0.05) / (darker + 0.05)
end

describe("UiTokens / paleta e geometria", function()
	it("cada par de texto/fundo declarado atinge o contraste mínimo do guia", function()
		expect(#UiTokens.contrastPairs > 0).toBeTruthy()
		for _, pair in ipairs(UiTokens.contrastPairs) do
			local fg = UiTokens.colors[pair.text]
			local bg = UiTokens.colors[pair.background]
			expect(fg).toBeTruthy()
			expect(bg).toBeTruthy()
			local ratio = contrast(fg, bg)
			if ratio < pair.minimum then
				error(
					string.format(
						"%s sobre %s = %.2f:1 (mínimo %.1f:1)",
						pair.text,
						pair.background,
						ratio,
						pair.minimum
					)
				)
			end
		end
	end)

	it("goldDark é só preenchimento: nenhum par de texto o usa", function()
		for _, pair in ipairs(UiTokens.contrastPairs) do
			expect(pair.text ~= "goldDark").toBeTruthy()
		end
	end)

	it("alvo de toque respeita 44 px mínimos e 48 px de meta", function()
		expect(UiTokens.touchMinimum).toBe(44)
		expect(UiTokens.touchTarget >= 48).toBeTruthy()
	end)

	it("camadas de renderização ficam na ordem mundo < HUD < menu < modal < toast", function()
		local order = UiTokens.displayOrder
		expect(order.world < order.hud).toBeTruthy()
		expect(order.hud < order.menu).toBeTruthy()
		expect(order.menu < order.modal).toBeTruthy()
		expect(order.modal < order.toast).toBeTruthy()
	end)

	it("raios, contorno e espaçamentos vêm do pacote de design", function()
		expect(UiTokens.radius.panel).toBe(20)
		expect(UiTokens.radius.button).toBe(12)
		expect(UiTokens.stroke).toBe(2)
		-- espaçamento em múltiplos de 4
		for _, value in ipairs(UiTokens.spacing) do
			expect(value % 4).toBe(0)
		end
	end)
end)

describe("UiMotion / receitas de animação", function()
	local EXPECTED = {
		hover_focus = 0.1,
		press = 0.08,
		panel_enter = 0.18,
		panel_exit = 0.12,
		modal_enter = 0.18,
		toast = 0.16,
		balance = 0.2,
		build = 0.18,
		upgrade = 0.35,
		result = 0.24,
		boss_warning = 2,
		cooldown = 0,
	}

	it("todas as receitas do guia existem com a duração documentada", function()
		for id, duration in pairs(EXPECTED) do
			local recipe = UiMotion[id]
			expect(recipe).toBeTruthy()
			expect(math.abs(recipe.duration - duration) < 0.0005).toBeTruthy()
		end
	end)

	it("o aviso de chefe mantém os 2 s definidos no combate", function()
		expect(UiMotion.boss_warning.duration).toBe(2)
	end)

	it("toda receita descreve a variante de movimento reduzido", function()
		for id, recipe in pairs(UiMotion) do
			if typeof(recipe) == "table" then
				expect(#recipe.reduced > 0).toBeTruthy()
				expect(#recipe.normal > 0).toBeTruthy()
				expect(recipe.style).toBeTruthy()
				expect(recipe.direction).toBeTruthy()
				expect(id ~= "").toBeTruthy()
			end
		end
	end)
end)

describe("UiIcons / biblioteca de ícones", function()
	it("os 24 ícones funcionais estão declarados", function()
		local count = 0
		for _ in pairs(UiIcons) do
			count += 1
		end
		expect(count).toBe(24)
	end)

	it("nenhum rbxassetid inventado: sem upload, image é nil", function()
		for key, icon in pairs(UiIcons) do
			if icon.image ~= nil then
				-- se algum dia houver upload real, o id precisa ser um rbxassetid numérico
				expect(typeof(icon.image)).toBe("string")
				expect(icon.image:match("^rbxassetid://%d+$") ~= nil).toBeTruthy()
			end
			expect(#icon.glyph > 0).toBeTruthy()
			expect(key:match("^ui_") ~= nil).toBeTruthy()
		end
	end)

	it("todo ícone tem rótulo acessível traduzido, em PT-BR e EN", function()
		for _, icon in pairs(UiIcons) do
			expect(Localization.has(icon.labelKey)).toBeTruthy()
		end
		expect(#Localization.missingKeys("en")).toBe(0)
	end)

	it("botões persistentes e sucata usam símbolos diferentes", function()
		expect(UiIcons.ui_buttons.glyph ~= UiIcons.ui_scrap.glyph).toBeTruthy()
		expect(UiIcons.ui_physical ~= nil).toBeTruthy()
		expect(UiIcons.ui_energy ~= nil).toBeTruthy()
		expect(UiIcons.ui_heal ~= nil).toBeTruthy()
	end)
end)
