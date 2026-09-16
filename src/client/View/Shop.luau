--!strict
-- Loja: exibe apenas quando o servidor confirma passe configurado e preço disponível.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Shop = {}
Shop.__index = Shop

local L = Localization.get

export type Callbacks = { onBack: () -> (), onQuery: (callback: (data: { [string]: any }) -> ()) -> (), onBuy: () -> () }

export type Shop = typeof(setmetatable({} :: { root: Frame, body: Frame, callbacks: Callbacks }, Shop))

function Shop.new(parent: GuiObject, callbacks: Callbacks): Shop
	local root = Ui.frame(
		parent,
		"Shop",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.paper, Visible = false }
	)
	local top = Ui.frame(
		root,
		"Top",
		{ Size = UDim2.new(1, -32, 0, 56), Position = UDim2.new(0, 16, 0, 12), BackgroundTransparency = 1 }
	)
	local back = Ui.button(top, "Back", "← " .. L("common.back"), "secondary", { Size = UDim2.new(0, 140, 0, 48) })
	back:onClick(callbacks.onBack)
	Ui.title(
		top,
		"Title",
		L("shop.title"),
		{ Size = UDim2.new(0, 300, 1, 0), Position = UDim2.new(0, 156, 0, 0), TextSize = 30 }
	)
	local body = Ui.panel(
		root,
		"Body",
		{ Size = UDim2.new(0, 520, 0, 260), Position = UDim2.new(0, 16, 0, 80), BackgroundColor3 = Theme.colors.cream }
	)
	Ui.padding(body, 16)
	return setmetatable({ root = root, body = body, callbacks = callbacks }, Shop) :: any
end

function Shop.render(self: Shop, data: { [string]: any })
	for _, c in ipairs(self.body:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local shop = data.shop or {}
	if not shop.enabled then
		Ui.label(self.body, "Disabled", L("shop.disabled"), { Size = UDim2.new(1, 0, 0, 60), TextSize = 16 })
		return
	end
	Ui.title(self.body, "Founder", L("shop.founder"), { Size = UDim2.new(1, 0, 0, 32), TextSize = 24 })
	Ui.label(
		self.body,
		"Desc",
		L("shop.founderDesc"),
		{ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 0, 36) }
	)
	local b = Ui.button(
		self.body,
		"Buy",
		if shop.owned then L("shop.owned") else L("shop.buy", { price = shop.priceRobux }),
		"primary",
		{ Size = UDim2.new(0, 260, 0, 48), Position = UDim2.new(0, 0, 0, 96) }
	)
	if shop.owned then
		b:setEnabled(false, "")
	end
	b:onClick(self.callbacks.onBuy)
end

function Shop.show(self: Shop)
	self.root.Visible = true
	Shop.render(self, { shop = { enabled = false } })
	self.callbacks.onQuery(function(data)
		if self.root.Visible then
			Shop.render(self, data)
		end
	end)
end

function Shop.hide(self: Shop)
	self.root.Visible = false
end

return Shop
