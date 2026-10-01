--!strict
-- Loja: fichas (Retomada e Reforço) e o passe Fundador.
--
-- Cada cartão diz o que entrega, o limite de uso e quantas o jogador já tem. O preço é o que o
-- Roblox devolveu para este jogador; sem preço (produto ainda não criado ou consulta falhou) o
-- botão de compra some e o cartão diz isso. Comprar abre a janela oficial do Roblox, e a ficha
-- só aparece no inventário quando o servidor confirmar o recibo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local CARD_W = 340

return function(scope: Kit.Scope, props: Props): Frame
	local shop = Bridge.use(scope, Atoms.shop)
	local profile = Bridge.use(scope, Atoms.profile)

	-- consulta a vitrine sempre que a loja abre (o preço pode mudar e o produto pode ter nascido)
	Bridge.watch(scope, function()
		return Atoms.route()
	end, function(route)
		if route == "shop" then
			GameFlow.queryShop()
		end
	end)

	-- Botão de um pacote: aparece só com preço real.
	local function packButton(productId: string, order: number): Frame
		local product = Products.get(productId)
		local quantity = if product then product.quantity else 1
		local offer = scope:Computed(function(use): { [string]: any }?
			local current = Kit.read(use, shop)
			if not current or typeof(current.products) ~= "table" then
				return nil
			end
			for _, entry in ipairs(current.products) do
				if entry.id == productId and entry.available then
					return entry
				end
			end
			return nil
		end)
		return Kit.button(scope, {
			name = "Buy_" .. productId,
			text = scope:Computed(function(use)
				local entry = Kit.read(use, offer)
				local price = if entry then entry.price else "?"
				if quantity == 1 then
					return L("shop.buyOne", { price = price })
				end
				return L("shop.buyMany", { quantity = quantity, price = price })
			end),
			kind = if quantity == 1 then "primary" else "secondary",
			visible = scope:Computed(function(use)
				return Kit.read(use, offer) ~= nil
			end),
			size = UDim2.new(1, 0, 0, 50),
			layoutOrder = order,
			zIndex = 4,
			onActivate = function()
				GameFlow.buyProduct(productId)
			end,
		})
	end

	local function itemCard(item: string, order: number): Frame
		local packs = Products.forItem(item :: any)
		local children: { any } = {
			Kit.title(scope, {
				Text = L("item." .. item),
				TextSize = 24,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 1,
				ZIndex = 4,
			}),
			Kit.text(scope, {
				Text = L(if item == "retry" then "item.retryDesc" else "item.supportDesc"),
				TextSize = 15,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				ZIndex = 4,
			}),
			Kit.caption(scope, {
				Text = L(if item == "retry" then "item.limitRetry" else "item.limitSupport") .. " " .. L(
					"item.assistNote"
				),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				ZIndex = 4,
			}),
			Kit.tag(scope, {
				text = scope:Computed(function(use)
					local _ = use(profile)
					return L("shop.youHave", { count = Selectors.itemCount(item) })
				end),
				color = Theme.colors.cyan,
				frame = { LayoutOrder = 4, ZIndex = 4 },
			}),
		}
		for index, product in ipairs(packs) do
			table.insert(children, packButton(product.id, 10 + index))
		end
		if item == "retry" then
			local price = scope:Computed(function(use)
				local current = Kit.read(use, shop)
				return if current and current.retryButtonsPrice then current.retryButtonsPrice else 0
			end)
			table.insert(
				children,
				Kit.button(scope, {
					name = "RetryButtons",
					text = scope:Computed(function(use)
						return L("shop.buyWithButtons", { price = Kit.read(use, price) })
					end),
					kind = "quiet",
					disabled = scope:Computed(function(use)
						local _ = Kit.read(use, profile)
						local cost = Kit.read(use, price)
						return cost <= 0 or Selectors.buttons() < cost
					end),
					size = UDim2.new(1, 0, 0, 46),
					layoutOrder = 30,
					zIndex = 4,
					onActivate = function()
						GameFlow.buyRetryWithButtons()
					end,
				})
			)
		end
		table.insert(
			children,
			Kit.caption(scope, {
				Name = "Unavailable",
				Text = L("shop.purchaseUnavailable"),
				Visible = scope:Computed(function(use)
					local _ = use(shop)
					return Selectors.offerFor(item) == nil
				end),
				TextColor3 = Theme.colors.muted,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 40,
				ZIndex = 4,
			})
		)
		return Kit.panel(scope, {
			name = "Item_" .. item,
			size = UDim2.new(0, CARD_W, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			layoutOrder = order,
			padding = 18,
			zIndex = 3,
			layout = Kit.list(scope, { Padding = UDim.new(0, 10) }),
			children = children,
		})
	end

	-- Passe Fundador: cosmético. Sem passe criado, o cartão explica em vez de oferecer.
	local founderCard = Kit.panel(scope, {
		name = "Founder",
		size = UDim2.new(0, CARD_W, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = 3,
		padding = 18,
		zIndex = 3,
		layout = Kit.list(scope, { Padding = UDim.new(0, 10) }),
		children = Kit.children(
			Kit.title(scope, {
				Text = L("shop.founder"),
				TextSize = 24,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 1,
				ZIndex = 4,
			}),
			Kit.text(scope, {
				Text = L("shop.founderDesc"),
				TextSize = 15,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				ZIndex = 4,
			}),
			Kit.caption(scope, {
				Text = scope:Computed(function(use)
					local current = Kit.read(use, shop)
					local founder = current and current.founder
					if not founder or not founder.enabled then
						return L("shop.disabled")
					end
					return L("shop.priceIs", { price = founder.price })
				end),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				ZIndex = 4,
			}),
			Kit.button(scope, {
				name = "BuyFounder",
				text = scope:Computed(function(use)
					local current = Kit.read(use, shop)
					local founder = current and current.founder
					return if founder and founder.owned then L("shop.owned") else L("shop.buyGeneric")
				end),
				kind = "primary",
				visible = scope:Computed(function(use)
					local current = Kit.read(use, shop)
					return current ~= nil and current.founder ~= nil and current.founder.enabled == true
				end),
				disabled = scope:Computed(function(use)
					local current = Kit.read(use, shop)
					return current ~= nil and current.founder ~= nil and current.founder.owned == true
				end),
				size = UDim2.new(1, 0, 0, 50),
				layoutOrder = 4,
				zIndex = 4,
				onActivate = function()
					Commands.send("shop:founder", "PromptFounderPass", {}, {
						onError = function(code)
							Actions.toast(L("error." .. code), "error")
						end,
					})
				end,
			})
		),
	})

	local screen = Kit.screen(scope, {
		name = "ShopScreen",
		title = L("shop.title"),
		subtitle = L("shop.itemsSubtitle"),
		visible = props.visible,
		scroll = true,
		onBack = function()
			if not Actions.back() then
				Actions.navigate("menu")
			end
		end,
		bodyLayout = Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 18),
			Wraps = true,
		}),
		children = Kit.children(itemCard("retry", 1), itemCard("support", 2), founderCard),
	})
	return screen.instance
end
