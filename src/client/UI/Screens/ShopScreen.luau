--!strict
-- 09_loja e 46_loja_estados: produto opcional com preço e posse verificados na plataforma.
--
-- Contrato:
--  * estados: consultando preço, indisponível, disponível, aguardando Roblox, cancelado e possuído;
--  * o preço vem da API e substitui o marcador — a expressão "{preço}" nunca aparece no jogo;
--  * a confirmação de compra é o fluxo nativo do Roblox; aqui não existe checkout desenhado;
--  * cancelar é neutro: não é erro, não penaliza e não concede nada;
--  * fechar o popup não concede: depois do prompt, a posse é reconsultada no servidor;
--  * falha de consulta remove a compra e mantém Voltar;
--  * a loja nunca bloqueia jogar.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)

local ShopScreen = {}
ShopScreen.__index = ShopScreen

local L = Localization.get

export type State = "querying" | "unavailable" | "available" | "waiting" | "cancelled" | "owned"

export type Callbacks = { onBack: () -> (), onCosmetics: () -> (), onShopState: (enabled: boolean) -> () }

export type ShopScreen = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		panel: Frame,
		statusLabel: TextLabel,
		detailLabel: TextLabel,
		buyButton: Components.Button,
		equipButton: Components.Button,
		refreshButton: Components.Button,
		state: State,
		priceText: string?,
	},
	ShopScreen
))

function ShopScreen.new(parent: Instance, callbacks: Callbacks): ShopScreen
	local self =
		setmetatable({ callbacks = callbacks, state = "querying" :: State, priceText = nil }, ShopScreen) :: any
	self.chrome = Chrome.new(parent, {
		name = "ShopScreen",
		title = L("shop.title"),
		subtitle = L("shop.subtitle"),
		onBack = callbacks.onBack,
	})
	local panel = Components.panel(self.chrome.body, "Product", {
		Size = UDim2.new(1, 0, 0, 280),
		ZIndex = 3,
	}, { tape = true, shadow = false })
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(640, 320)
	maxWidth.Parent = panel
	Components.padding(panel, 20, 18)
	self.panel = panel

	Components.title(panel, "Name", L("shop.founder"), {
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 26,
		ZIndex = 4,
	})
	Components.label(panel, "Desc", L("shop.founderDesc"), {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 38),
		ZIndex = 4,
	})
	self.statusLabel = Components.label(panel, "Status", "", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 90),
		Font = Theme.fonts.bodyBold,
		ZIndex = 4,
	})
	self.detailLabel = Components.caption(panel, "Detail", "", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 116),
		ZIndex = 4,
	})

	local row = Components.frame(panel, "Row", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
		Position = UDim2.new(0, 0, 1, -Theme.sizes.buttonTarget),
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 12)
	self.refreshButton = Components.button(row, {
		name = "Refresh",
		text = L("common.retry"),
		kind = "secondary",
		size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 5,
		visible = false,
		onActivate = function()
			ShopScreen.query(self)
		end,
	})
	self.equipButton = Components.button(row, {
		name = "Equip",
		text = L("shop.equipLooks"),
		kind = "secondary",
		size = UDim2.fromOffset(260, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 5,
		visible = false,
		onActivate = callbacks.onCosmetics,
	})
	self.buyButton = Components.button(row, {
		name = "Buy",
		text = L("shop.buyGeneric"),
		kind = "primary",
		size = UDim2.fromOffset(300, Theme.sizes.buttonTarget),
		layoutOrder = 3,
		zIndex = 5,
		visible = false,
		onActivate = function()
			ShopScreen.buy(self)
		end,
	})

	Components.caption(self.chrome.body, "PlayNote", L("shop.neverBlocks"), {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 296),
		ZIndex = 3,
	})
	return self
end

local function apply(self: ShopScreen, state: State, detail: string?)
	self.state = state
	self.buyButton.instance.Visible = state == "available" or state == "cancelled"
	self.equipButton.instance.Visible = state == "owned"
	self.refreshButton.instance.Visible = state == "unavailable" or state == "cancelled"
	self.detailLabel.Text = detail or ""
	if state == "querying" then
		self.statusLabel.Text = L("shop.querying")
	elseif state == "unavailable" then
		self.statusLabel.Text = L("shop.unavailable")
	elseif state == "available" then
		-- o rótulo só é montado com um preço real vindo da plataforma
		self.statusLabel.Text = L("shop.priceIs", { price = self.priceText or "" })
		self.buyButton:setText(L("shop.buy", { price = self.priceText or "" }))
		self.buyButton:setAvailable(true)
	elseif state == "waiting" then
		self.statusLabel.Text = L("shop.waitingRoblox")
	elseif state == "cancelled" then
		-- cancelamento é neutro: não é erro e não penaliza
		self.statusLabel.Text = L("shop.cancelled")
		self.buyButton:setText(L("shop.buy", { price = self.priceText or "" }))
		self.buyButton:setPending(false)
	elseif state == "owned" then
		self.statusLabel.Text = L("shop.owned")
	end
end

function ShopScreen.query(self: ShopScreen)
	apply(self, "querying")
	CommandAdapter.send("shop:query", "QueryShop", {}, {
		onSuccess = function(response)
			local shop = response.shop or {}
			self.callbacks.onShopState(shop.enabled == true)
			if not shop.enabled then
				apply(
					self,
					"unavailable",
					if shop.reason == "price_unavailable" then L("shop.priceUnavailable") else L("shop.disabled")
				)
				return
			end
			if shop.owned then
				apply(self, "owned", L("shop.ownedDetail"))
				return
			end
			if typeof(shop.priceRobux) ~= "number" then
				apply(self, "unavailable", L("shop.priceUnavailable"))
				return
			end
			self.priceText = tostring(shop.priceRobux)
			apply(self, "available", L("shop.availableDetail"))
		end,
		onError = function()
			self.callbacks.onShopState(false)
			apply(self, "unavailable", L("shop.queryFailed"))
		end,
	})
end

function ShopScreen.buy(self: ShopScreen)
	if self.state ~= "available" and self.state ~= "cancelled" then
		return
	end
	self.buyButton:setPending(true, L("shop.waitingRoblox"))
	apply(self, "waiting", L("shop.waitingDetail"))
	CommandAdapter.send("shop:prompt", "PromptFounderPass", {}, {
		onSuccess = function()
			-- o popup é do Roblox. Fechar o popup não concede nada: a posse é reconsultada
			-- no servidor antes de qualquer mudança de estado.
			task.delay(1.5, function()
				if self.chrome.root.Visible then
					self.buyButton:setPending(false)
					ShopScreen.query(self)
				end
			end)
		end,
		onError = function(code)
			self.buyButton:setPending(false)
			if code == "SHOP_DISABLED" then
				apply(self, "unavailable", L("shop.disabled"))
			else
				apply(self, "cancelled", L("shop.cancelledDetail"))
			end
		end,
	})
end

function ShopScreen.show(self: ShopScreen)
	self.chrome:show()
	ShopScreen.query(self)
end

function ShopScreen.hide(self: ShopScreen)
	self.chrome:hide()
end

return ShopScreen
