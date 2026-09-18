--!strict
-- ARQUIVO GERADO por tools/export_ui_icons.py a partir de ui_asset_registry.json.
-- image == nil significa ícone ainda não publicado: o cliente desenha o glifo de reserva
-- e mantém o rótulo textual, que nunca depende do desenho.

export type Icon = { image: string?, glyph: string, labelKey: string, size: number }

local UiIcons: { [string]: Icon } = {
	ui_back = {
		glyph = "‹",
		labelKey = "icon.back",
		size = 128,
	},
	ui_base = {
		glyph = "⌂",
		labelKey = "icon.base",
		size = 128,
	},
	ui_buttons = {
		glyph = "◉",
		labelKey = "icon.buttons",
		size = 128,
	},
	ui_check = {
		glyph = "✓",
		labelKey = "icon.check",
		size = 128,
	},
	ui_close = {
		glyph = "✕",
		labelKey = "icon.close",
		size = 128,
	},
	ui_cooldown = {
		glyph = "◷",
		labelKey = "icon.cooldown",
		size = 128,
	},
	ui_energy = {
		glyph = "◈",
		labelKey = "icon.energy",
		size = 128,
	},
	ui_error = {
		glyph = "!",
		labelKey = "icon.error",
		size = 128,
	},
	ui_group = {
		glyph = "◍",
		labelKey = "icon.group",
		size = 128,
	},
	ui_heal = {
		glyph = "+",
		labelKey = "icon.heal",
		size = 128,
	},
	ui_lock = {
		glyph = "🔒",
		labelKey = "icon.lock",
		size = 128,
	},
	ui_minus = {
		glyph = "−",
		labelKey = "icon.minus",
		size = 128,
	},
	ui_physical = {
		glyph = "⛨",
		labelKey = "icon.physical",
		size = 128,
	},
	ui_play = {
		glyph = "▶",
		labelKey = "icon.play",
		size = 128,
	},
	ui_plus = {
		glyph = "+",
		labelKey = "icon.plus",
		size = 128,
	},
	ui_pulse = {
		glyph = "✷",
		labelKey = "icon.pulse",
		size = 128,
	},
	ui_scrap = {
		glyph = "✦",
		labelKey = "icon.scrap",
		size = 128,
	},
	ui_sell = {
		glyph = "⌫",
		labelKey = "icon.sell",
		size = 128,
	},
	ui_settings = {
		glyph = "⚙",
		labelKey = "icon.settings",
		size = 128,
	},
	ui_speed = {
		glyph = "»",
		labelKey = "icon.speed",
		size = 128,
	},
	ui_target = {
		glyph = "◎",
		labelKey = "icon.target",
		size = 128,
	},
	ui_upgrade = {
		glyph = "▲",
		labelKey = "icon.upgrade",
		size = 128,
	},
	ui_volume = {
		glyph = "🔊",
		labelKey = "icon.volume",
		size = 128,
	},
	ui_wave = {
		glyph = "〜",
		labelKey = "icon.wave",
		size = 128,
	},
}

return UiIcons
