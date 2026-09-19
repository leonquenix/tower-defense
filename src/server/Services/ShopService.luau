--!strict
-- Loja: um passe permanente opcional. Desligada por padrão; sem ID válido nada é exibido nem concedido.
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Products = require(Shared.Config.Products)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)

local ShopService = {}

local priceCache: { price: number?, fetchedAt: number } = { price = nil, fetchedAt = 0 }

local function fetchPrice(): number?
	local passId = Products.founderPassId
	if not passId then
		return nil
	end
	if os.clock() - priceCache.fetchedAt < 300 and priceCache.price then
		return priceCache.price
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and typeof(info) == "table" and typeof((info :: any).PriceInRobux) == "number" then
		priceCache.price = (info :: any).PriceInRobux
		priceCache.fetchedAt = os.clock()
		return priceCache.price
	end
	return nil
end

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

function ShopService.query(player: Player): { [string]: any }
	if not Products.isShopAvailable() then
		return { enabled = false }
	end
	local price = fetchPrice()
	if not price then
		return { enabled = false, reason = "price_unavailable" }
	end
	local owned = ownsPass(player)
	if owned then
		grantFounder(player)
	end
	return { enabled = true, priceRobux = price, owned = owned, passId = Products.founderPassId }
end

function ShopService.prompt(player: Player): (boolean, string?)
	if not Products.isShopAvailable() or not fetchPrice() then
		return false, "SHOP_DISABLED"
	end
	local passId = Products.founderPassId :: number
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
	return ok, if ok then nil else "INVALID_STATE"
end

function ShopService.init()
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
end

return ShopService
