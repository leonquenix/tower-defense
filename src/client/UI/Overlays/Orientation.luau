--!strict
-- Aviso de orientação (prancha 30): em celular retrato, o jogo pede para girar.
-- A partida continua rodando no servidor — o texto diz isso em vez de sugerir que parou.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

return function(scope: Kit.Scope): Frame
	local warning = Bridge.use(scope, Atoms.orientationWarning)
	local inMatch = Bridge.use(scope, Atoms.inMatch)

	return scope:New("Frame")({
		Name = "Orientation",
		BackgroundColor3 = Theme.colors.inkDeep,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = warning,
		Active = true,
		ZIndex = 60,
		[Children] = Kit.children(Kit.panel(scope, {
			name = "Card",
			size = UDim2.new(0, 420, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			padding = 24,
			zIndex = 61,
			layout = Kit.list(scope, { Padding = UDim.new(0, 12) }),
			children = Kit.children(
				Kit.title(scope, {
					Text = L("orientation.rotate"),
					TextSize = 26,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 1,
					ZIndex = 62,
				}),
				Kit.text(scope, {
					Text = L("orientation.note"),
					TextColor3 = Theme.colors.muted,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
					ZIndex = 62,
				}),
				Kit.caption(scope, {
					Text = L("orientation.matchContinues"),
					Visible = inMatch,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 3,
					ZIndex = 62,
				}),
				Kit.button(scope, {
					name = "Settings",
					text = L("menu.settings"),
					kind = "secondary",
					icon = "ui_settings",
					size = UDim2.new(0, 220, 0, 48),
					layoutOrder = 4,
					zIndex = 62,
					onActivate = function()
						Actions.push("settings")
					end,
				})
			),
		})),
	})
end
