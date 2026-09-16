--!strict
-- Configurações: volumes, movimento reduzido, partículas, números de dano, padrão de Circuitos e idioma.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local SettingsController = require(script.Parent.Parent.Controllers.SettingsController)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local Settings = {}
Settings.__index = Settings

local L = Localization.get

export type Callbacks = { onBack: () -> (), onSave: (settings: Types.ProfileSettings) -> () }

export type Settings = typeof(setmetatable(
	{} :: {
		root: Frame,
		body: Frame,
		callbacks: Callbacks,
		refreshHeader: () -> (),
	},
	Settings
))

function Settings.new(parent: GuiObject, callbacks: Callbacks): Settings
	local root = Ui.frame(
		parent,
		"Settings",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.paper, Visible = false }
	)
	local self = setmetatable({ root = root, callbacks = callbacks }, Settings) :: any
	local top = Ui.frame(
		root,
		"Top",
		{ Size = UDim2.new(1, -32, 0, 56), Position = UDim2.new(0, 16, 0, 12), BackgroundTransparency = 1 }
	)
	local back = Ui.button(top, "Back", "← " .. L("common.back"), "secondary", { Size = UDim2.new(0, 140, 0, 48) })
	back:onClick(function()
		callbacks.onSave(SettingsController.get())
		callbacks.onBack()
	end)
	local title = Ui.title(
		top,
		"Title",
		L("settings.title"),
		{ Size = UDim2.new(0, 300, 1, 0), Position = UDim2.new(0, 156, 0, 0), TextSize = 30 }
	)
	local body = Ui.panel(
		root,
		"Body",
		{ Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 80), BackgroundColor3 = Theme.colors.cream }
	)
	Ui.padding(body, 16)
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(640, 4000)
	maxWidth.Parent = body
	Ui.list(body, Enum.FillDirection.Vertical, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	self.body = body
	self.refreshHeader = function()
		title.Text = L("settings.title")
		back:setText("← " .. L("common.back"))
	end
	return self
end

local function row(parent: Frame, order: number, labelText: string): Frame
	local r = Ui.frame(
		parent,
		"Row" .. order,
		{ Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = order }
	)
	Ui.label(r, "Label", labelText, { Size = UDim2.new(0.5, 0, 1, 0), Font = Theme.fonts.bodyMedium })
	return r
end

local function volumeRow(parent: Frame, order: number, labelText: string, key: string, self: Settings)
	local r = row(parent, order, labelText)
	local value = SettingsController.get()[key] :: number
	local minus = Ui.button(
		r,
		"Minus",
		"−",
		"secondary",
		{ Size = UDim2.new(0, 48, 0, 44), Position = UDim2.new(0.5, 0, 0, 2) }
	)
	local text = Ui.label(r, "Value", tostring(math.floor(value * 100 + 0.5)) .. "%", {
		Size = UDim2.new(0, 70, 1, 0),
		Position = UDim2.new(0.5, 56, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.fonts.numbers,
		TextSize = 18,
	})
	local plus =
		Ui.button(r, "Plus", "+", "secondary", { Size = UDim2.new(0, 48, 0, 44), Position = UDim2.new(0.5, 134, 0, 2) })
	local function set(v: number)
		v = math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1)
		SettingsController.set(key, v)
		text.Text = tostring(math.floor(v * 100 + 0.5)) .. "%"
		AudioController.play("ui_click")
	end
	minus:onClick(function()
		set((SettingsController.get()[key] :: number) - 0.1)
	end)
	plus:onClick(function()
		set((SettingsController.get()[key] :: number) + 0.1)
	end)
end

local function toggleRow(parent: Frame, order: number, labelText: string, key: string)
	local r = row(parent, order, labelText)
	local b =
		Ui.button(r, "Toggle", "", "secondary", { Size = UDim2.new(0, 130, 0, 44), Position = UDim2.new(0.5, 0, 0, 2) })
	local function refresh()
		local on = SettingsController.get()[key] == true
		b:setText(if on then L("common.yes") else L("common.no"))
		b:setKind(if on then "primary" else "secondary")
	end
	b:onClick(function()
		SettingsController.set(key, not (SettingsController.get()[key] == true))
		refresh()
	end)
	refresh()
end

local function choiceRow(
	parent: Frame,
	order: number,
	labelText: string,
	key: string,
	choices: { { value: string, label: string } },
	onChange: (() -> ())?
)
	local r = row(parent, order, labelText)
	local holder = Ui.frame(
		r,
		"Choices",
		{ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundTransparency = 1 }
	)
	Ui.list(holder, Enum.FillDirection.Horizontal, 6)
	local buttons: { [string]: Ui.Button } = {}
	local function refresh()
		local current = SettingsController.get()[key]
		for v, b in pairs(buttons) do
			b:setKind(if v == current then "primary" else "secondary")
		end
	end
	for i, c in ipairs(choices) do
		local b = Ui.button(holder, c.value, c.label, "secondary", { Size = UDim2.new(0, 130, 0, 44), LayoutOrder = i })
		b.label.TextSize = 14
		b:onClick(function()
			SettingsController.set(key, c.value)
			refresh()
			if onChange then
				onChange()
			end
		end)
		buttons[c.value] = b
	end
	refresh()
end

function Settings.render(self: Settings)
	self.refreshHeader()
	for _, c in ipairs(self.body:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	volumeRow(self.body, 1, L("settings.music"), "musicVolume", self)
	volumeRow(self.body, 2, L("settings.sfx"), "sfxVolume", self)
	toggleRow(self.body, 3, L("settings.reducedMotion"), "reducedMotion")
	toggleRow(self.body, 4, L("settings.reducedParticles"), "reducedParticles")
	toggleRow(self.body, 5, L("settings.damageNumbers"), "damageNumbers")
	choiceRow(self.body, 6, L("settings.circuitPattern"), "circuitPattern", {
		{ value = "solid", label = L("settings.circuitPattern.solid") },
		{ value = "dashed", label = L("settings.circuitPattern.dashed") },
	})
	choiceRow(self.body, 7, L("settings.locale"), "locale", {
		{ value = "pt-br", label = L("settings.locale.ptbr") },
		{ value = "en", label = L("settings.locale.en") },
	}, function()
		Settings.render(self)
	end)
	Ui.label(
		self.body,
		"AudioNote",
		L("settings.audioMissing"),
		{ Size = UDim2.new(1, 0, 0, 40), TextSize = 12, TextColor3 = Theme.colors.muted, LayoutOrder = 8 }
	)
end

function Settings.show(self: Settings)
	self.root.Visible = true
	Settings.render(self)
end

function Settings.hide(self: Settings)
	self.root.Visible = false
end

return Settings
