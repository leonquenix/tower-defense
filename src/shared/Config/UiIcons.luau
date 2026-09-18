--!strict
-- ARQUIVO GERADO por tools/export_ui_icons.py a partir de ui_asset_registry.json.
-- image == nil significa ícone ainda não publicado: o cliente desenha o glifo de reserva
-- e mantém o rótulo textual, que nunca depende do desenho.

export type Icon = { image: string?, glyph: string, labelKey: string, size: number }

local UiIcons: { [string]: Icon } = {
	ui_back = {
		glyph = "‹",
		image = "rbxassetid://88491749815381",
		labelKey = "icon.back",
		size = 128,
	},
	ui_base = {
		glyph = "⌂",
		image = "rbxassetid://111920601725235",
		labelKey = "icon.base",
		size = 128,
	},
	ui_buttons = {
		glyph = "◉",
		image = "rbxassetid://101246403255603",
		labelKey = "icon.buttons",
		size = 128,
	},
	ui_check = {
		glyph = "✓",
		image = "rbxassetid://104059787042270",
		labelKey = "icon.check",
		size = 128,
	},
	ui_close = {
		glyph = "✕",
		image = "rbxassetid://118214159540710",
		labelKey = "icon.close",
		size = 128,
	},
	ui_cooldown = {
		glyph = "◷",
		image = "rbxassetid://82684451501253",
		labelKey = "icon.cooldown",
		size = 128,
	},
	ui_energy = {
		glyph = "◈",
		image = "rbxassetid://131805218762416",
		labelKey = "icon.energy",
		size = 128,
	},
	ui_error = {
		glyph = "!",
		image = "rbxassetid://104020383943624",
		labelKey = "icon.error",
		size = 128,
	},
	ui_group = {
		glyph = "◍",
		image = "rbxassetid://101185371000335",
		labelKey = "icon.group",
		size = 128,
	},
	ui_heal = {
		glyph = "+",
		image = "rbxassetid://83533878039427",
		labelKey = "icon.heal",
		size = 128,
	},
	ui_lock = {
		glyph = "🔒",
		image = "rbxassetid://104319975182301",
		labelKey = "icon.lock",
		size = 128,
	},
	ui_minus = {
		glyph = "−",
		image = "rbxassetid://139587755350316",
		labelKey = "icon.minus",
		size = 128,
	},
	ui_physical = {
		glyph = "⛨",
		image = "rbxassetid://110488708842551",
		labelKey = "icon.physical",
		size = 128,
	},
	ui_play = {
		glyph = "▶",
		image = "rbxassetid://76972323672777",
		labelKey = "icon.play",
		size = 128,
	},
	ui_plus = {
		glyph = "+",
		image = "rbxassetid://112814833650940",
		labelKey = "icon.plus",
		size = 128,
	},
	ui_pulse = {
		glyph = "✷",
		image = "rbxassetid://77488608610057",
		labelKey = "icon.pulse",
		size = 128,
	},
	ui_scrap = {
		glyph = "✦",
		image = "rbxassetid://93292805807152",
		labelKey = "icon.scrap",
		size = 128,
	},
	ui_sell = {
		glyph = "⌫",
		image = "rbxassetid://101007725063284",
		labelKey = "icon.sell",
		size = 128,
	},
	ui_settings = {
		glyph = "⚙",
		image = "rbxassetid://110525661692700",
		labelKey = "icon.settings",
		size = 128,
	},
	ui_speed = {
		glyph = "»",
		image = "rbxassetid://78000524487354",
		labelKey = "icon.speed",
		size = 128,
	},
	ui_target = {
		glyph = "◎",
		image = "rbxassetid://94414571956685",
		labelKey = "icon.target",
		size = 128,
	},
	ui_upgrade = {
		glyph = "▲",
		image = "rbxassetid://125880091131026",
		labelKey = "icon.upgrade",
		size = 128,
	},
	ui_volume = {
		glyph = "🔊",
		image = "rbxassetid://100558525605931",
		labelKey = "icon.volume",
		size = 128,
	},
	ui_wave = {
		glyph = "〜",
		image = "rbxassetid://126556458277057",
		labelKey = "icon.wave",
		size = 128,
	},
}

return UiIcons
