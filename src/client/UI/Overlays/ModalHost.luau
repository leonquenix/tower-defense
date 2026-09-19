--!strict
-- Modal bloqueador da prancha 38: scrim, título, corpo e duas saídas. Um por vez.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local L = Localization.get

return function(scope: Kit.Scope): Frame
	local modal = Bridge.use(scope, Atoms.modal)
	local visible = scope:Computed(function(use)
		return use(modal) ~= nil
	end)

	local function close()
		local current = peek(modal)
		Actions.closeModal()
		if current and current.onCancel then
			current.onCancel()
		end
	end

	return scope:New("Frame")({
		Name = "ModalHost",
		BackgroundColor3 = Theme.colors.inkDeep,
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(visible) then 0.45 else 1
			end),
			TweenInfo.new(0.18, Enum.EasingStyle.Quad)
		),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		Active = true,
		ZIndex = 40,
		[Children] = Kit.children(
			-- toque fora do painel cancela (mesma ação do botão de cancelar)
			scope:New("TextButton")({
				Name = "Scrim",
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 40,
				[OnEvent("Activated")] = close,
			}),
			Kit.panel(scope, {
				name = "Dialog",
				size = UDim2.new(0, 420, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				padding = 22,
				zIndex = 41,
				layout = Kit.list(scope, { Padding = UDim.new(0, 12) }),
				children = {
					Kit.title(scope, {
						Name = "Title",
						Text = scope:Computed(function(use)
							local current = use(modal)
							return if current then current.title else ""
						end),
						TextSize = 24,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 1,
						ZIndex = 42,
					}),
					Kit.text(scope, {
						Name = "Body",
						Text = scope:Computed(function(use)
							local current = use(modal)
							return if current then (current.body or "") else ""
						end),
						Visible = scope:Computed(function(use)
							local current = use(modal)
							return current ~= nil and (current.body or "") ~= ""
						end),
						TextColor3 = Theme.colors.muted,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 2,
						ZIndex = 42,
					}),
					scope:New("Frame")({
						Name = "Actions",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
						LayoutOrder = 3,
						ZIndex = 42,
						[Children] = Kit.children(
							Kit.list(scope, {
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 10),
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							Kit.button(scope, {
								name = "Cancel",
								text = scope:Computed(function(use)
									local current = use(modal)
									return (current and current.cancelText) or L("common.cancel")
								end),
								kind = "secondary",
								size = UDim2.new(0, 140, 0, Theme.sizes.buttonTarget),
								layoutOrder = 1,
								zIndex = 43,
								onActivate = close,
							}),
							Kit.button(scope, {
								name = "Confirm",
								text = scope:Computed(function(use)
									local current = use(modal)
									if current and current.pending then
										return L("common.confirming")
									end
									return (current and current.confirmText) or L("common.confirm")
								end),
								kind = scope:Computed(function(use)
									local current = use(modal)
									return if current and current.danger then "danger" else "primary"
								end),
								disabled = scope:Computed(function(use)
									local current = use(modal)
									return current ~= nil and current.pending == true
								end),
								size = UDim2.new(0, 170, 0, Theme.sizes.buttonTarget),
								layoutOrder = 2,
								zIndex = 43,
								onActivate = function()
									local current = peek(modal)
									if not current then
										return
									end
									if current.onConfirm then
										current.onConfirm()
									else
										Actions.closeModal()
									end
								end,
							})
						),
					}),
				},
			})
		),
	})
end
