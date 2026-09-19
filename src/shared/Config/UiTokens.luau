--!strict
-- ARQUIVO GERADO por tools/import_ui_tokens.py a partir de
-- UI_Quintal_em_Guarda_v1/dados/design_tokens.json (sha256 463eda976694154e4c79b33df044bd873b31c8eaf80ccc085ce6c37ca61adaae)
-- Não edite à mão: altere o JSON e rode a ferramenta.
-- Cores em RGB 0-255; use UiTokens.color(name) para obter um Color3.

local UiTokens = {
	colors = {
		backdrop = { 20, 32, 47 },
		coral = { 255, 119, 94 },
		cream = { 255, 243, 214 },
		creamDark = { 241, 226, 190 },
		cyan = { 99, 205, 232 },
		danger = { 182, 62, 72 },
		dangerSoft = { 252, 230, 226 },
		enemy = { 125, 99, 184 },
		forest = { 15, 42, 30 },
		forestMid = { 27, 70, 48 },
		glowWarm = { 255, 233, 168 },
		gold = { 255, 200, 87 },
		goldDark = { 217, 165, 62 },
		goldText = { 138, 94, 18 },
		ink = { 25, 40, 63 },
		inkDeep = { 13, 22, 38 },
		leaf = { 47, 122, 79 },
		leafLight = { 95, 168, 106 },
		muted = { 82, 97, 116 },
		night = { 218, 212, 237 },
		nightDark = { 159, 156, 178 },
		paper = { 255, 250, 236 },
		sage = { 219, 232, 215 },
		sageDeep = { 203, 221, 198 },
		sand = { 255, 225, 160 },
		sandDark = { 206, 172, 113 },
		skyHigh = { 27, 58, 82 },
		tape = { 247, 234, 201 },
		tapeDark = { 198, 187, 167 },
		teal = { 47, 183, 160 },
		tealDark = { 24, 112, 95 },
		white = { 255, 255, 255 },
	},
	contrastPairs = {
		{
			background = "paper",
			minimum = 4.5,
			ratio = 14.22,
			text = "ink",
		},
		{
			background = "cream",
			minimum = 4.5,
			ratio = 13.44,
			text = "ink",
		},
		{
			background = "gold",
			minimum = 4.5,
			ratio = 9.64,
			text = "ink",
		},
		{
			background = "sage",
			minimum = 4.5,
			ratio = 11.67,
			text = "ink",
		},
		{
			background = "cyan",
			minimum = 4.5,
			ratio = 8.07,
			text = "ink",
		},
		{
			background = "creamDark",
			minimum = 4.5,
			ratio = 11.55,
			text = "ink",
		},
		{
			background = "sageDeep",
			minimum = 4.5,
			ratio = 10.37,
			text = "ink",
		},
		{
			background = "paper",
			minimum = 4.5,
			ratio = 6.06,
			text = "muted",
		},
		{
			background = "cream",
			minimum = 4.5,
			ratio = 5.73,
			text = "muted",
		},
		{
			background = "sage",
			minimum = 4.5,
			ratio = 4.98,
			text = "muted",
		},
		{
			background = "dangerSoft",
			minimum = 4.5,
			ratio = 4.65,
			text = "danger",
		},
		{
			background = "paper",
			minimum = 4.5,
			ratio = 5.34,
			text = "danger",
		},
		{
			background = "ink",
			minimum = 4.5,
			ratio = 13.44,
			text = "cream",
		},
		{
			background = "paper",
			minimum = 4.5,
			ratio = 5.72,
			text = "tealDark",
		},
		{
			background = "paper",
			minimum = 4.5,
			ratio = 5.46,
			text = "goldText",
		},
		{
			background = "cream",
			minimum = 4.5,
			ratio = 5.16,
			text = "goldText",
		},
		{
			background = "sage",
			minimum = 4.5,
			ratio = 4.7,
			text = "tealDark",
		},
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
