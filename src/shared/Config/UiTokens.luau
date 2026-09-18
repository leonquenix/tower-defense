--!strict
-- ARQUIVO GERADO por tools/import_ui_tokens.py a partir de
-- UI_Quintal_em_Guarda_v1/dados/design_tokens.json (sha256 463eda976694154e4c79b33df044bd873b31c8eaf80ccc085ce6c37ca61adaae)
-- Não edite à mão: altere o JSON e rode a ferramenta.
-- Cores em RGB 0-255; use UiTokens.color(name) para obter um Color3.

local UiTokens = {
	colors = {
		coral = { 255, 119, 94 },
		cream = { 255, 243, 214 },
		cyan = { 99, 205, 232 },
		danger = { 182, 62, 72 },
		enemy = { 125, 99, 184 },
		gold = { 255, 200, 87 },
		ink = { 25, 40, 63 },
		muted = { 82, 97, 116 },
		paper = { 255, 250, 236 },
		sage = { 219, 232, 215 },
		teal = { 47, 183, 160 },
	},
	displayOrder = {
		hud = 10,
		menu = 20,
		modal = 30,
		toast = 40,
		world = 0,
	},
	radius = {
		button = 12,
		panel = 20,
		pill = 15,
	},
	referenceDesktop = { 1280, 720 },
	referenceMobile = { 844, 390 },
	spacing = { 4, 8, 12, 16, 24, 32, 48 },
	stroke = 2,
	text = {
		body = 18,
		button = 19,
		caption = 14,
		hero = 65,
		title = 30,
	},
	touchMinimum = 44,
	touchTarget = 48,
}

local cache: { [string]: Color3 } = {}

-- Color3 memoizado a partir do RGB do token.
function UiTokens.color(name: string): Color3
	local hit = cache[name]
	if hit then
		return hit
	end
	local rgb = (UiTokens.colors :: any)[name]
	assert(rgb, `token de cor desconhecido: {name}`)
	local made = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	cache[name] = made
	return made
end

return UiTokens
