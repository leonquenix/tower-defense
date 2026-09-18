--!strict
-- Paleta e tipografia da direção de arte.
-- As cores funcionais vêm de Config/UiTokens (gerado de dados/design_tokens.json); as variações
-- de apoio (creamDark, goldDark, caminhos de mapa…) são derivadas e continuam definidas aqui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTokens = require(ReplicatedStorage.Shared.Config.UiTokens)

local Theme = {}

Theme.tokens = UiTokens

Theme.colors = {
	ink = UiTokens.color("ink"),
	cream = UiTokens.color("cream"),
	creamDark = Color3.fromHex("F1E2BE"),
	teal = UiTokens.color("teal"),
	tealDark = Color3.fromHex("1F8C7A"),
	gold = UiTokens.color("gold"),
	goldDark = Color3.fromHex("D9A53E"),
	coral = UiTokens.color("coral"),
	enemy = UiTokens.color("enemy"),
	cyan = UiTokens.color("cyan"),
	danger = UiTokens.color("danger"),
	dangerSoft = Color3.fromHex("FBE0DC"),
	-- #526174 escurece o muted original para atingir 4,5:1 sobre creme (guia, paleta funcional)
	muted = UiTokens.color("muted"),
	white = Color3.fromHex("FFFFFF"),
	-- superfície de ficha (Paper) e fundo verde suave (Sage) da direção de arte
	surface = UiTokens.color("paper"),
	sage = UiTokens.color("sage"),
	sageDeep = Color3.fromHex("CBDDC6"),
	paper = Color3.fromHex("F4F1E9"),
	sand = Color3.fromHex("FFE1A0"),
	sandDark = Color3.fromHex("CEAC71"),
	tape = Color3.fromHex("F7EAC9"),
	tapeDark = Color3.fromHex("C6BBA7"),
	night = Color3.fromHex("DAD4ED"),
	nightDark = Color3.fromHex("9F9CB2"),
	backdrop = Color3.fromHex("14202F"),
}

-- Cores e formas de dono (círculo, quadrado, triângulo, losango)
Theme.owners = {
	{ color = Color3.fromHex("FFC857"), glyph = "●" },
	{ color = Color3.fromHex("63CDE8"), glyph = "■" },
	{ color = Color3.fromHex("FF775E"), glyph = "▲" },
	{ color = Color3.fromHex("2FB7A0"), glyph = "◆" },
}

Theme.pathColors = {
	jardim = { Theme.colors.sand, Theme.colors.sandDark },
	oficina = { Theme.colors.tape, Theme.colors.tapeDark },
	sotao = { Theme.colors.night, Theme.colors.nightDark },
}

Theme.fonts = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.BuilderSans,
	bodyMedium = Enum.Font.BuilderSansMedium,
	bodyBold = Enum.Font.BuilderSansBold,
	numbers = Enum.Font.BuilderSansBold,
}

Theme.sizes = {
	corner = UiTokens.radius.button,
	panelCorner = UiTokens.radius.panel,
	pillCorner = UiTokens.radius.pill,
	stroke = UiTokens.stroke,
	focusStroke = 3,
	caption = UiTokens.text.caption,
	body = 16,
	bodyLarge = UiTokens.text.body,
	button = UiTokens.text.button,
	numbers = 22,
	title = UiTokens.text.title,
	hero = UiTokens.text.hero,
	buttonMin = UiTokens.touchMinimum,
	buttonTarget = UiTokens.touchTarget,
}

-- Camadas de renderização (decisões locais; não substituem a CoreGui)
Theme.displayOrder = UiTokens.displayOrder

Theme.towerColors = {
	dardo = Color3.fromHex("FF8A3D"),
	pipoca = Color3.fromHex("F3C623"),
	lupa = Color3.fromHex("C9A46A"),
	goma = Color3.fromHex("7EE0C8"),
	voltz = Color3.fromHex("63CDE8"),
	maestro = Color3.fromHex("FF775E"),
}

Theme.towerGlyphs = {
	dardo = "D",
	pipoca = "P",
	lupa = "L",
	goma = "G",
	voltz = "V",
	maestro = "M",
}

return Theme
