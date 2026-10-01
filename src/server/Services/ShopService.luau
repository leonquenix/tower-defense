--!strict
-- Loja: o passe Fundador (cosmético) e as fichas vendidas como Developer Products (Retomada e
-- Reforço).
--
-- Regras de compra (docs/MONETIZACAO.md):
--  * o cliente só pede para abrir a janela oficial do Roblox; preço e entrega nunca vêm dele;
--  * fechar a janela não é compra: quem entrega é o recibo (ProcessReceipt), um roteador só;
--  * o recibo soma a ficha no perfil, grava e só então responde "entregue". Recibo repetido
--    (queda, outro servidor) não soma de novo: o PurchaseId fica registrado no perfil;
--  * comprar só guarda a ficha. Usar é outra ação, que a partida valida.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Balance = require(Shared.Config.Balance)
local Products = require(Shared.Config.Products)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local Server = require(script.Parent.Parent.Net.Server)

local ShopService = {}

local PRICE_TTL = 300

type PriceEntry = { price: number?, fetchedAt: number }
local priceCache: { [string]: PriceEntry } = {}

-- Avisado quando alguém abre a janela de compra (a partida estende o prazo da derrota).
local onPromptOpened: ((Player) -> ())? = nil

local function cachedPrice(key: string, fetch: () -> number?): number?
	local entry = priceCache[key]
	if entry and entry.price and os.clock() - entry.fetchedAt < PRICE_TTL then
		return entry.price
	end
	local price = fetch()
	priceCache[key] = { price = price, fetchedAt = os.clock() }
	return price
end

local function infoPrice(assetId: number, infoType: Enum.InfoType): number?
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, infoType)
	end)
	if ok and typeof(info) == "table" and typeof((info :: any).PriceInRobux) == "number" then
		return (info :: any).PriceInRobux
	end
	return nil
end

local function founderPrice(): number?
	local passId = Products.founderPassId
	if not passId then
		return nil
	end
	return cachedPrice("founder", function()
		return infoPrice(passId, Enum.InfoType.GamePass)
	end)
end

-- Preço de um produto de ficha (nil = sem produto criado ou consulta falhou: compra escondida).
local function productPrice(product: Types.ProductDef): number?
	local robloxId = product.productId
	if not robloxId then
		return nil
	end
	return cachedPrice(product.id, function()
		return infoPrice(robloxId, Enum.InfoType.Product)
	end)
end

local function itemEnabled(item: Types.ItemId): boolean
	if item == "retry" then
		return Products.retryEnabled
	end
	return Products.supportEnabled
end

-- ---------------------------------------------------------------------------
-- Passe Fundador
-- ---------------------------------------------------------------------------

local function ownsPass(player: Player): boolean
	local passId = Products.founderPassId
	if not passId then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns == true
end

local function grantFounder(player: Player)
	PlayerDataService.mutate(player, function(p: Types.Profile)
		for _, c in ipairs(Products.founderCosmetics) do
			if table.find(p.cosmeticsOwned, c.id) == nil then
				table.insert(p.cosmeticsOwned, c.id)
			end
		end
	end)
	TelemetryService.log("founder_granted", { userId = player.UserId })
end

-- ---------------------------------------------------------------------------
-- Consulta
-- ---------------------------------------------------------------------------

-- O que a tela de loja (e a de derrota) pode oferecer agora, com o preço real do Roblox.
function ShopService.query(player: Player): { [string]: any }
	local products: { { [string]: any } } = {}
	for _, product in ipairs(Products.list()) do
		local price = if itemEnabled(product.item) then productPrice(product) else nil
		table.insert(products, {
			id = product.id,
			item = product.item,
			quantity = product.quantity,
			price = price,
			available = price ~= nil,
		})
	end
	local founder: { [string]: any } = { enabled = false }
	if Products.isShopAvailable() then
		local price = founderPrice()
		if price then
			local owned = ownsPass(player)
			if owned then
				grantFounder(player)
			end
			founder = { enabled = true, price = price, owned = owned }
		else
			founder = { enabled = false, reason = "price_unavailable" }
		end
	end
	return {
		products = products,
		founder = founder,
		retryButtonsPrice = Balance.shop.retry.buttonsPrice,
	}
end

-- ---------------------------------------------------------------------------
-- Janelas de compra
-- ---------------------------------------------------------------------------

function ShopService.promptFounder(player: Player): (boolean, string?)
	if not Products.isShopAvailable() or not founderPrice() then
		return false, "SHOP_DISABLED"
	end
	local passId = Products.founderPassId :: number
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
	return ok, if ok then nil else "INVALID_STATE"
end

-- Abre a janela oficial de um produto de ficha. Nada é entregue aqui.
function ShopService.promptProduct(player: Player, productKey: string): (boolean, string?)
	local product = Products.get(productKey)
	if not product or not product.productId or not itemEnabled(product.item) then
		return false, "SHOP_DISABLED"
	end
	if not productPrice(product) then
		return false, "SHOP_DISABLED"
	end
	local robloxId = product.productId :: number
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, robloxId)
	end)
	if not ok then
		return false, "INVALID_STATE"
	end
	TelemetryService.log("purchase_intent", { userId = player.UserId, product = product.id })
	if onPromptOpened then
		onPromptOpened(player)
	end
	return true, nil
end

-- ---------------------------------------------------------------------------
-- Entrega (recibo)
-- ---------------------------------------------------------------------------

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = Products.byRobloxId(receipt.ProductId)
	if not product then
		-- produto que este servidor não conhece (versão antiga?): deixa para outro servidor
		TelemetryService.log("receipt_unknown_product", { productId = receipt.ProductId })
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local status = PlayerDataService.getStatus(player)
	if status ~= "ready" and status ~= "volatile" then
		-- perfil ainda não carregou (ou está travado em outro servidor): o Roblox tenta de novo
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local granted = false
	local duplicate = false
	local mutated = PlayerDataService.mutate(player, function(p: Types.Profile)
		granted, duplicate = ProfileSchema.applyPurchase(p, purchaseId, product.item, product.quantity, os.time())
	end)
	if not mutated or (not granted and not duplicate) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- só confirma para o Roblox quando o recibo já está gravado
	local saved = PlayerDataService.saveAndConfirm(player, function(data: any): boolean
		return typeof(data) == "table" and typeof(data.purchases) == "table" and data.purchases[purchaseId] ~= nil
	end)
	if not saved then
		TelemetryService.log("receipt_not_saved", { userId = player.UserId, product = product.id })
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted then
		local profile = PlayerDataService.get(player)
		TelemetryService.log("receipt_granted", {
			userId = player.UserId,
			product = product.id,
			robux = receipt.CurrencySpent,
		})
		TelemetryService.economy(
			player,
			true,
			product.item,
			product.quantity,
			if profile then profile.inventory[product.item] else 0,
			"IAP",
			product.id
		)
		Server.sendLobby(player, "purchase", {
			item = product.item,
			quantity = product.quantity,
			profile = PlayerDataService.clientView(player),
		})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.init(callbacks: { onPromptOpened: ((Player) -> ())? }?)
	onPromptOpened = if callbacks then callbacks.onPromptOpened else nil
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not Products.isShopAvailable() or passId ~= Products.founderPassId then
				return
			end
			-- o evento apenas indica fechamento do popup; a posse é verificada na API
			if purchased and ownsPass(player) then
				grantFounder(player)
			else
				TelemetryService.log("founder_prompt_closed", { userId = player.UserId, purchased = purchased })
			end
		end
	)
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			-- informativo: a entrega é do recibo. Fechar sem comprar vira telemetria de funil.
			TelemetryService.log("prompt_closed", { userId = userId, productId = productId, purchased = purchased })
		end
	)
end

return ShopService
