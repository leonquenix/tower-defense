--!strict
-- 30_orientacao: explicar a orientação suportada sem tirar o acesso às opções.
--
-- Contrato:
--  * pedir para girar com ilustração simples; nunca forçar paisagem por API;
--  * Configurações continua acessível; "Voltar ao menu" passa por confirmação se houver partida ativa;
--  * durante o combate, o texto diz "A partida continua" para não passar impressão de pausa;
--  * ao girar, o layout é reconstruído preservando seleção e estado — girar não cria comando novo
--    nem fecha uma confirmação aberta (esta tela não desmonta modais);
--  * nada de anunciar gameplay vertical otimizado.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)

local Orientation = {}
Orientation.__index = Orientation

local L = Localization.get

export type Callbacks = { onSettings: () -> (), onMenu: () -> () }

export type Orientation = typeof(setmetatable(
	{} :: {
		root: Frame,
		callbacks: Callbacks,
		noteLabel: TextLabel,
		buttons: { Components.Button },
		inMatch: boolean,
	},
	Orientation
))

function Orientation.new(parent: Instance, callbacks: Callbacks): Orientation
	local root = Components.frame(parent, "Orientation", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
		Visible = false,
		ZIndex = 30,
	})
	root.Active = true
	local panel = Components.panel(root, "Panel", {
		Size = UDim2.new(1, -48, 0, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 31,
	}, { tape = true, shadow = false })
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(360, 460)
	constraint.Parent = panel
	Components.padding(panel, 22, 20)

	-- ilustração simples: retângulo deitado com uma seta de giro, tudo nativo
	local art = Components.frame(panel, "Art", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		ZIndex = 32,
	})
	art.Active = false
	local device = Components.frame(art, "Device", {
		Size = UDim2.fromOffset(190, 118),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.cream,
		ZIndex = 32,
	})
	device.Active = false
	Components.corner(device, 16)
	Components.stroke(device, Theme.colors.ink, 3)
	local screen = Components.frame(device, "Screen", {
		Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.colors.sageDeep,
		ZIndex = 33,
	})
	screen.Active = false
	Components.corner(screen, 10)
	local arrow = Components.label(art, "Arrow", "↻", {
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromScale(0.82, 0.22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 48,
		TextColor3 = Theme.colors.teal,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		ZIndex = 33,
	})
	arrow.Active = false

	Components.title(panel, "Title", L("orientation.rotate"), {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 158),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 32,
	})

	local self = setmetatable({ root = root, callbacks = callbacks, buttons = {}, inMatch = false }, Orientation) :: any

	self.noteLabel = Components.label(panel, "Note", L("orientation.note"), {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 220),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.muted,
		TextSize = Theme.sizes.body,
		ZIndex = 32,
	})

	local actions = Components.frame(panel, "Actions", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget * 2 + 12),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget * 2 + 12)),
		BackgroundTransparency = 1,
		ZIndex = 32,
	})
	local layout = Components.list(actions, Enum.FillDirection.Vertical, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	table.insert(
		self.buttons,
		Components.button(actions, {
			name = "Settings",
			text = L("menu.settings"),
			kind = "secondary",
			icon = "ui_settings",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			layoutOrder = 1,
			zIndex = 33,
			onActivate = callbacks.onSettings,
		})
	)
	table.insert(
		self.buttons,
		Components.button(actions, {
			name = "Menu",
			text = L("result.menu"),
			kind = "ghost",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = 33,
			onActivate = callbacks.onMenu,
		})
	)
	return self
end

function Orientation.setVisible(self: Orientation, visible: boolean, inMatch: boolean)
	if self.inMatch ~= inMatch then
		self.inMatch = inMatch
		self.noteLabel.Text = if inMatch then L("orientation.matchContinues") else L("orientation.note")
	end
	if self.root.Visible ~= visible then
		self.root.Visible = visible
	end
end

function Orientation.isVisible(self: Orientation): boolean
	return self.root.Visible
end

return Orientation
