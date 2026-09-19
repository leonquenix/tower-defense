--!strict
-- Entrada: enquanto o perfil carrega. Depois de alguns segundos explica a demora e oferece
-- tentar de novo ou entrar no treino — nunca finge que carregou nem grava um perfil vazio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean>, elapsed: Fusion.UsedAs<number> }

local SLOW_AFTER = 6

return function(scope: Kit.Scope, props: Props): Frame
	local status = Bridge.use(scope, Atoms.profileStatus)
	local slow = scope:Computed(function(use)
		return Kit.read(use, props.elapsed) >= SLOW_AFTER
	end)

	return scope:New("Frame")({
		Name = "BootScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible,
		[Children] = Kit.children(Kit.panel(scope, {
			name = "Card",
			size = UDim2.new(0, 520, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			padding = 28,
			layout = Kit.list(scope, { Padding = UDim.new(0, 14) }),
			children = Kit.children(
				Kit.title(scope, {
					Text = L("app.title"),
					TextSize = 34,
					Size = UDim2.new(1, 0, 0, 40),
					LayoutOrder = 1,
					ZIndex = 3,
				}),
				Kit.text(scope, {
					Name = "Status",
					Text = scope:Computed(function(use)
						local current = use(status)
						if current == "unavailable" or current == "locked" then
							return L("app.profileUnavailable")
						end
						return L("boot.profile")
					end),
					TextColor3 = Theme.colors.muted,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
					ZIndex = 3,
				}),
				-- barra de progresso indeterminada: só sinaliza atividade, não promete prazo
				Kit.bar(scope, {
					value = scope:Computed(function(use)
						local elapsed: number = Kit.read(use, props.elapsed)
						return math.min((elapsed % 3) / 3, 1)
					end),
					color = Theme.colors.cyan,
					height = 8,
					layoutOrder = 3,
				}),
				Kit.caption(scope, {
					Name = "Slow",
					Text = L("boot.slow"),
					Visible = slow,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 4,
					ZIndex = 3,
				}),
				Kit.caption(scope, {
					Name = "NoDefaults",
					Text = L("boot.noDefaults"),
					Visible = slow,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 5,
					ZIndex = 3,
				}),
				scope:New("Frame")({
					Name = "Actions",
					BackgroundTransparency = 1,
					Visible = slow,
					Size = UDim2.new(1, 0, 0, 52),
					LayoutOrder = 6,
					ZIndex = 3,
					[Children] = Kit.children(
						Kit.list(scope, {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 10),
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Kit.button(scope, {
							name = "Retry",
							text = L("common.retry"),
							kind = "primary",
							size = UDim2.fromOffset(200, 48),
							layoutOrder = 1,
							zIndex = 4,
							onActivate = GameFlow.retryProfile,
						}),
						Kit.button(scope, {
							name = "Training",
							text = L("boot.training"),
							kind = "secondary",
							size = UDim2.fromOffset(200, 48),
							layoutOrder = 2,
							zIndex = 4,
							onActivate = function()
								GameFlow.startTraining("jardim")
							end,
						}),
						Kit.button(scope, {
							name = "Settings",
							text = L("menu.settings"),
							kind = "quiet",
							icon = "ui_settings",
							size = UDim2.fromOffset(180, 48),
							layoutOrder = 3,
							zIndex = 4,
							onActivate = function()
								Actions.push("settings")
							end,
						})
					),
				})
			),
		})),
	})
end
