--!strict
-- Paleta e tipografia da direção de arte.
-- As cores funcionais vêm de Config/UiTokens (gerado de dados/design_tokens.json); as variações
-- de apoio (creamDark, goldDark, caminhos de mapa…) são derivadas e continuam definidas aqui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTokens = require(ReplicatedStorage.Shared.Config.UiTokens)

local Theme = {}

Theme.tokens = UiTokens

-- Toda a paleta (tokens e variações de apoio) vem de UiTokens, que já valida o contraste
-- dos pares de texto/fundo ao ser gerado.
Theme.colors = {
	ink = UiTokens.color("ink"),
	cream = UiTokens.color("cream"),
	creamDark = UiTokens.color("creamDark"),
	teal = UiTokens.color("teal"),
	tealDark = UiTokens.color("tealDark"),
	gold = UiTokens.color("gold"),
	goldDark = UiTokens.color("goldDark"), -- preenchimento, nunca texto
	goldText = UiTokens.color("goldText"), -- âmbar legível para números e rótulos
	coral = UiTokens.color("coral"),
	enemy = UiTokens.color("enemy"),
	cyan = UiTokens.color("cyan"),
	danger = UiTokens.color("danger"),
	dangerSoft = UiTokens.color("dangerSoft"),
	muted = UiTokens.color("muted"),
	white = UiTokens.color("white"),
	surface = UiTokens.color("paper"),
	sage = UiTokens.color("sage"),
	sageDeep = UiTokens.color("sageDeep"),
	paper = UiTokens.color("paper"),
	sand = UiTokens.color("sand"),
	sandDark = UiTokens.color("sandDark"),
	tape = UiTokens.color("tape"),
	tapeDark = UiTokens.color("tapeDark"),
	night = UiTokens.color("night"),
	nightDark = UiTokens.color("nightDark"),
	backdrop = UiTokens.color("backdrop"),
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
