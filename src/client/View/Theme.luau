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
	-- cenário ilustrado do revamp (só preenchimento: nenhuma dessas carrega texto)
	forest = UiTokens.color("forest"),
	forestMid = UiTokens.color("forestMid"),
	leaf = UiTokens.color("leaf"),
	leafLight = UiTokens.color("leafLight"),
	skyHigh = UiTokens.color("skyHigh"),
	glowWarm = UiTokens.color("glowWarm"),
	grass = UiTokens.color("grass"), -- botão de iniciar onda
	grassDeep = UiTokens.color("grassDeep"), -- espessura do botão verde (preenchimento)
	inkDeep = UiTokens.color("inkDeep"),
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
	-- mapas da encomenda v2: só valem enquanto a cena desenhada não é publicada
	inverno = { Color3.fromHex("EFC98A"), Color3.fromHex("B88A4A") },
	cozinha = { Color3.fromHex("FFF6E3"), Color3.fromHex("C9A97A") },
	quarto = { Color3.fromHex("E9CFA0"), Color3.fromHex("9A7046") },
	porao = { Color3.fromHex("EADFC8"), Color3.fromHex("8E8AA0") },
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
	-- encomenda v2 (paletas da seção 5): azul-real, lima, vermelho, ardósia e caramelo
	escova = Color3.fromHex("3FC1B0"),
	lumi = Color3.fromHex("3D6FD6"),
	pula = Color3.fromHex("8BC34A"),
	piao = Color3.fromHex("D8453B"),
	picole = Color3.fromHex("34507A"),
	fofo = Color3.fromHex("D9A066"),
}

Theme.towerGlyphs = {
	dardo = "D",
	pipoca = "P",
	lupa = "L",
	goma = "G",
	voltz = "V",
	maestro = "M",
	escova = "E",
	lumi = "U",
	pula = "J",
	piao = "O",
	picole = "C",
	fofo = "F",
}

return Theme
