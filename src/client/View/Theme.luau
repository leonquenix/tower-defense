--!strict
-- Paleta e tipografia da direção de arte.
local Theme = {}

Theme.colors = {
	ink = Color3.fromHex("19283F"),
	cream = Color3.fromHex("FFF3D6"),
	creamDark = Color3.fromHex("F1E2BE"),
	teal = Color3.fromHex("2FB7A0"),
	tealDark = Color3.fromHex("1F8C7A"),
	gold = Color3.fromHex("FFC857"),
	goldDark = Color3.fromHex("D9A53E"),
	coral = Color3.fromHex("FF775E"),
	enemy = Color3.fromHex("7D63B8"),
	cyan = Color3.fromHex("63CDE8"),
	danger = Color3.fromHex("B63E48"),
	dangerSoft = Color3.fromHex("FBE0DC"),
	muted = Color3.fromHex("66768A"),
	white = Color3.fromHex("FFFFFF"),
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
	corner = 12,
	stroke = 2,
	body = 16,
	bodyLarge = 18,
	numbers = 22,
	title = 30,
	buttonMin = 44,
	buttonTarget = 48,
}

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
