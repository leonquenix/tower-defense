--!strict
-- Loja: um item opcional, sem vantagem de jogo. Sem passe criado, a tela diz isso em vez de
-- mostrar um botão que não faz nada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

return function(scope: Kit.Scope, props: Props): Frame
	local price: Fusion.Value<string> = scope:Value(L("shop.querying"))
	local owned: Fusion.Value<boolean> = scope:Value(false)
	local available: Fusion.Value<boolean> = scope:Value(Products.isShopAvailable())

	local function query()
		Commands.send("shop:query", "QueryShop", {}, {
			onSuccess = function(response)
				available:set(response.enabled == true)
				owned:set(response.owned == true)
				if typeof(response.price) == "number" then
					price:set(L("shop.priceIs", { price = response.price }))
				else
					price:set(L("shop.priceUnavailable"))
				end
			end,
			onError = function()
				price:set(L("shop.queryFailed"))
			end,
		})
	end
	query()

	local screen = Kit.screen(scope, {
		name = "ShopScreen",
		title = L("shop.title"),
		subtitle = L("shop.subtitle"),
		visible = props.visible,
		onBack = function()
			if not Actions.back() then
				Actions.navigate("menu")
			end
		end,
		children = Kit.children(Kit.panel(scope, {
			name = "Founder",
			size = UDim2.new(0, 520, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			padding = 22,
			zIndex = 3,
			layout = Kit.list(scope, { Padding = UDim.new(0, 12) }),
			children = Kit.children(
				Kit.title(scope, {
					Text = L("shop.founder"),
					TextSize = 26,
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = 1,
					ZIndex = 4,
				}),
				Kit.text(scope, {
					Text = L("shop.founderDesc"),
					TextColor3 = Theme.colors.muted,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
					ZIndex = 4,
				}),
				Kit.caption(scope, {
					Text = price,
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = 3,
					ZIndex = 4,
				}),
				Kit.caption(scope, {
					Name = "Disabled",
					Text = L("shop.disabled"),
					Visible = scope:Computed(function(use)
						return not use(available)
					end),
					TextColor3 = Theme.colors.danger,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 4,
					ZIndex = 4,
				}),
				Kit.button(scope, {
					name = "Buy",
					text = scope:Computed(function(use)
						return if use(owned) then L("shop.owned") else L("shop.buyGeneric")
					end),
					sub = L("shop.availableDetail"),
					kind = "primary",
					disabled = scope:Computed(function(use)
						return not Kit.read(use, available) or Kit.read(use, owned)
					end),
					size = UDim2.new(0, 280, 0, 56),
					layoutOrder = 5,
					zIndex = 4,
					onActivate = function()
						Commands.send("shop:prompt", "PromptFounderPass", {}, {
							onError = function(code)
								Actions.toast(L("error." .. code), "error")
							end,
						})
					end,
				}),
				Kit.button(scope, {
					name = "Refresh",
					text = L("common.retry"),
					kind = "quiet",
					size = UDim2.new(0, 200, 0, 48),
					layoutOrder = 6,
					zIndex = 4,
					onActivate = query,
				})
			),
		})),
	})
	return screen.instance
end
