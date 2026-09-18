--!strict
-- 10_opcoes: ajustar conforto sem abandonar a partida.
--
-- Contrato:
--  * abre de qualquer origem e volta para a mesma origem (a pilha do Router cuida disso);
--  * a partida NÃO pausa, nem no solo — o texto diz isso explicitamente;
--  * sliders de 5% aceitam clique na trilha, arrasto e os botões menos/mais (nunca só arrasto);
--  * toggles trazem texto Ligado/Desligado e ícone: a cor não é a única pista;
--  * mudanças valem na hora, localmente; o salvamento é agrupado após 500 ms — sem pedido por frame;
--  * falha ao salvar mostra "Preferências não salvas" e permite repetir;
--  * a preferência de movimento reduzido do Roblox soma com a opção do jogo (qualquer uma ativa o modo);
--  * a CoreGui nunca é escondida.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Accessibility = require(script.Parent.Parent.Accessibility)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local SettingsController = require(script.Parent.Parent.Parent.Controllers.SettingsController)

local SettingsScreen = {}
SettingsScreen.__index = SettingsScreen

local L = Localization.get

local SAVE_DEBOUNCE = 0.5

export type Callbacks = { onDone: () -> () }

export type SettingsScreen = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		content: ScrollingFrame,
		footer: Frame,
		buttons: { Components.Button },
		sliders: { Components.Slider },
		saveToken: number,
		statusLabel: TextLabel,
		inMatch: boolean,
	},
	SettingsScreen
))

function SettingsScreen.new(parent: Instance, callbacks: Callbacks): SettingsScreen
	local self = setmetatable({
		callbacks = callbacks,
		buttons = {},
		sliders = {},
		saveToken = 0,
		inMatch = false,
	}, SettingsScreen) :: any
	self.chrome = Chrome.new(parent, {
		name = "SettingsScreen",
		title = L("settings.title"),
		showBalance = false,
		onBack = function()
			SettingsScreen.flush(self)
			callbacks.onDone()
		end,
	})
	local body = self.chrome.body
	self.content = Components.scroller(body, "Content", {
		Size = UDim2.new(1, 0, 1, -(Theme.sizes.buttonTarget + 20)),
		ZIndex = 2,
	})
	local layout = Components.list(self.content, Enum.FillDirection.Vertical, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	self.footer = Components.frame(body, "Footer", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 8),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget + 8)),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	Components.list(self.footer, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	self.statusLabel = Components.caption(self.footer, "Status", "", {
		Size = UDim2.new(1, -300, 0, 24),
		LayoutOrder = 1,
		TextColor3 = Theme.colors.danger,
		Visible = false,
		ZIndex = 4,
	})
	return self
end

-- Salvamento agrupado: cada mudança reinicia a janela de 500 ms; um pedido por lote.
function SettingsScreen.scheduleSave(self: SettingsScreen)
	self.saveToken += 1
	local token = self.saveToken
	task.delay(SAVE_DEBOUNCE, function()
		if token ~= self.saveToken then
			return
		end
		SettingsScreen.save(self)
	end)
end

function SettingsScreen.flush(self: SettingsScreen)
	if self.saveToken > 0 then
		self.saveToken += 1
		SettingsScreen.save(self)
	end
end

function SettingsScreen.save(self: SettingsScreen)
	local settings: Types.ProfileSettings = SettingsController.get()
	CommandAdapter.send("profile:settings", "SaveSettings", {
		musicVolume = settings.musicVolume,
		sfxVolume = settings.sfxVolume,
		reducedMotion = settings.reducedMotion,
		reducedParticles = settings.reducedParticles,
		damageNumbers = settings.damageNumbers,
		circuitPattern = settings.circuitPattern,
		locale = settings.locale,
	}, {
		onSuccess = function()
			self.statusLabel.Visible = false
		end,
		onError = function()
			-- local já mudou; o que falhou foi a persistência. O texto diz exatamente isso.
			self.statusLabel.Text = L("settings.notSaved")
			self.statusLabel.Visible = true
		end,
	})
end

local function sectionTitle(self: SettingsScreen, text: string, order: number)
	Components.label(self.content, "T" .. order, Components.upper(text), {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
		LayoutOrder = order,
		ZIndex = 3,
	})
end

local function row(self: SettingsScreen, name: string, labelText: string, order: number, height: number?): Frame
	local card = Components.panel(self.content, name, {
		Size = UDim2.new(1, 0, 0, height or (Theme.sizes.buttonTarget + 20)),
		LayoutOrder = order,
		ZIndex = 3,
	}, { shadow = false })
	Components.padding(card, 16, 10)
	Components.label(card, "Label", labelText, {
		Size = UDim2.new(0.38, 0, 1, 0),
		Font = Theme.fonts.bodyMedium,
		ZIndex = 4,
	})
	return card
end

function SettingsScreen.render(self: SettingsScreen)
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	for _, slider in ipairs(self.sliders) do
		slider:destroy()
	end
	table.clear(self.sliders)
	for _, child in ipairs(self.content:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in ipairs(self.footer:GetChildren()) do
		if child:IsA("GuiObject") and child ~= self.statusLabel then
			child:Destroy()
		end
	end

	self.chrome:setTitle(L("settings.title"), if self.inMatch then L("settings.matchContinues") else nil)

	sectionTitle(self, L("settings.audio"), 1)
	local volumeKeys = {
		{ key = "musicVolume", label = L("settings.music") },
		{
			key = "sfxVolume",
			label = L("settings.sfx"),
		},
	}
	for index, entry in ipairs(volumeKeys) do
		local card = row(self, "Vol" .. index, entry.label, index + 1)
		local slider = Components.slider(
			card,
			"Slider",
			(SettingsController.get() :: any)[entry.key] :: number,
			function(value: number)
				SettingsController.set(entry.key, value)
				SettingsScreen.scheduleSave(self)
			end,
			{
				Size = UDim2.new(0.62, 0, 1, 0),
				Position = UDim2.new(0.38, 0, 0, 0),
				ZIndex = 4,
			}
		)
		table.insert(self.sliders, slider)
	end
	Components.caption(self.content, "AudioNote", L("settings.audioMissing"), {
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 4,
		ZIndex = 3,
	})

	sectionTitle(self, L("settings.comfort"), 5)
	local toggles = {
		{ key = "reducedMotion", label = L("settings.reducedMotion"), hint = L("settings.reducedMotionHint") },
		{ key = "reducedParticles", label = L("settings.reducedParticles"), hint = "" },
		{ key = "damageNumbers", label = L("settings.damageNumbers"), hint = "" },
	}
	for index, entry in ipairs(toggles) do
		local card = row(self, "Toggle" .. index, entry.label, index + 5, if entry.hint ~= "" then 88 else nil)
		if entry.hint ~= "" then
			Components.caption(card, "Hint", entry.hint, {
				Size = UDim2.new(0.38, -8, 0, 40),
				Position = UDim2.fromOffset(0, 30),
				ZIndex = 4,
			})
		end
		local toggle = Components.toggle(
			card,
			"Value",
			(SettingsController.get() :: any)[entry.key] == true,
			function(value: boolean)
				SettingsController.set(entry.key, value)
				SettingsScreen.scheduleSave(self)
				if entry.key == "reducedMotion" then
					SettingsScreen.render(self)
				end
			end,
			{ Size = UDim2.fromOffset(200, Theme.sizes.buttonTarget), Position = UDim2.new(0.38, 0, 0, 2), ZIndex = 4 }
		)
		table.insert(self.buttons, toggle.button)
	end
	-- o modo efetivo pode estar ligado por causa da preferência do Roblox, mesmo com a opção desligada
	if Accessibility.reducedMotion() and not SettingsController.get().reducedMotion then
		Components.caption(self.content, "SystemReduced", L("settings.systemReducedMotion"), {
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 9,
			TextColor3 = Theme.colors.tealDark,
			ZIndex = 3,
		})
	end

	local patternCard = row(self, "Pattern", L("settings.circuitPattern"), 10)
	local patternHolder = Components.frame(patternCard, "Choices", {
		Size = UDim2.new(0.62, 0, 1, 0),
		Position = UDim2.new(0.38, 0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	Components.list(patternHolder, Enum.FillDirection.Horizontal, 8)
	local patternButtons: { [string]: Components.Button } = {}
	for index, value in ipairs({ "solid", "dashed" }) do
		local button = Components.button(patternHolder, {
			name = value,
			text = L("settings.circuitPattern." .. value),
			kind = "secondary",
			size = UDim2.fromOffset(180, Theme.sizes.buttonTarget),
			layoutOrder = index,
			zIndex = 5,
			onActivate = function()
				SettingsController.set("circuitPattern", value)
				for id, other in pairs(patternButtons) do
					other:setSelected(id == value)
				end
				SettingsScreen.scheduleSave(self)
			end,
		})
		button:setSelected(SettingsController.get().circuitPattern == value)
		patternButtons[value] = button
		table.insert(self.buttons, button)
	end

	sectionTitle(self, L("settings.language"), 11)
	local localeCard = row(self, "Locale", L("settings.locale"), 12)
	local localeHolder = Components.frame(localeCard, "Choices", {
		Size = UDim2.new(0.62, 0, 1, 0),
		Position = UDim2.new(0.38, 0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	Components.list(localeHolder, Enum.FillDirection.Horizontal, 8)
	for index, value in ipairs({ "pt-br", "en" }) do
		local button = Components.button(localeHolder, {
			name = value,
			text = L("settings.locale." .. (if value == "pt-br" then "ptbr" else "en")),
			kind = "secondary",
			size = UDim2.fromOffset(180, Theme.sizes.buttonTarget),
			layoutOrder = index,
			zIndex = 5,
			onActivate = function()
				SettingsController.set("locale", value)
				SettingsScreen.scheduleSave(self)
				-- trocar o idioma redesenha a tela inteira: nenhum texto fica embutido em imagem
				SettingsScreen.render(self)
			end,
		})
		button:setSelected(SettingsController.get().locale == value)
		table.insert(self.buttons, button)
	end

	if self.inMatch then
		Components.caption(self.content, "MatchNote", L("settings.matchContinuesLong"), {
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 13,
			ZIndex = 3,
		})
	end

	local done = Components.button(self.footer, {
		name = "Done",
		text = L("settings.done"),
		kind = "primary",
		icon = "ui_check",
		size = UDim2.fromOffset(276, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 4,
		onActivate = function()
			SettingsScreen.flush(self)
			self.callbacks.onDone()
		end,
	})
	table.insert(self.buttons, done)
end

function SettingsScreen.show(self: SettingsScreen, params: { [string]: any }?)
	self.inMatch = params ~= nil and params.inMatch == true
	self.chrome:show()
	self.statusLabel.Visible = false
	SettingsScreen.render(self)
end

function SettingsScreen.hide(self: SettingsScreen)
	SettingsScreen.flush(self)
	self.chrome:hide()
end

return SettingsScreen
