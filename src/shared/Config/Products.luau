--!strict
-- Configuração de loja. A loja fica desativada até existir um passe criado no Creator Hub
-- e o ID ser preenchido aqui (ver docs/MANUAL_ACTIONS.md). Sem ID válido, o botão de compra não aparece.
local Balance = require(script.Parent.Balance)
local Types = require(script.Parent.Parent.Types)

export type CosmeticDef = { id: string, kind: "skin" | "banner" | "title" | "sticker", towerId: string?, source: string }

local Products = {}

local founderPassId: number? = Balance.shop.founderPassId -- nil até criação real no Creator Hub
Products.shopEnabled = Balance.shop.enabledByDefault -- falso por padrão
Products.founderPassId = founderPassId
Products.proposedRobuxPrice = Balance.shop.proposedRobuxPrice -- hipótese; o preço real vem da API

-- Cosméticos previstos do Pacote Fundador (arte ainda não produzida: ver MANUAL_ACTIONS)
local founderCosmetics: { CosmeticDef } = {
	{ id = "skin_dardo_fundador", kind = "skin", towerId = "dardo", source = "founder" },
	{ id = "skin_pipoca_fundador", kind = "skin", towerId = "pipoca", source = "founder" },
	{ id = "skin_lupa_fundador", kind = "skin", towerId = "lupa", source = "founder" },
	{ id = "skin_goma_fundador", kind = "skin", towerId = "goma", source = "founder" },
	{ id = "skin_voltz_fundador", kind = "skin", towerId = "voltz", source = "founder" },
	{ id = "skin_maestro_fundador", kind = "skin", towerId = "maestro", source = "founder" },
	{ id = "banner_fundador", kind = "banner", source = "founder" },
	{ id = "title_fundador", kind = "title", source = "founder" },
}
Products.founderCosmetics = founderCosmetics

-- Cosméticos de domínio (30 adesivo, 100 título, 250 variação de skin) por torre
function Products.masteryCosmetics(towerId: string): { [number]: CosmeticDef }
	return {
		[30] = { id = "sticker_" .. towerId, kind = "sticker", towerId = towerId, source = "mastery" },
		[100] = { id = "title_" .. towerId, kind = "title", towerId = towerId, source = "mastery" },
		[250] = { id = "skin_" .. towerId .. "_dominio", kind = "skin", towerId = towerId, source = "mastery" },
	}
end

function Products.isShopAvailable(): boolean
	return Products.shopEnabled and founderPassId ~= nil
end

-- ---------------------------------------------------------------------------
-- Fichas (Developer Products)
-- ---------------------------------------------------------------------------
-- Cada produto entrega um item fixo: um "retry_3" vendido hoje continua entregando 3 Retomadas
-- mesmo se a oferta mudar. Produto novo = chave nova. O ID do Roblox fica nil até o produto ser
-- criado no Creator Hub; sem ID, a compra simplesmente não aparece.
local productsById: { [string]: Types.ProductDef } = {}
local productsByRobloxId: { [number]: Types.ProductDef } = {}
for _, product in ipairs(Balance.shop.products) do
	productsById[product.id] = product
	if product.productId then
		productsByRobloxId[product.productId] = product
	end
end

Products.retryEnabled = Balance.shop.retry.enabled
Products.supportEnabled = Balance.shop.support.enabled

function Products.list(): { Types.ProductDef }
	return Balance.shop.products
end

function Products.get(id: string): Types.ProductDef?
	return productsById[id]
end

function Products.byRobloxId(productId: number): Types.ProductDef?
	return productsByRobloxId[productId]
end

-- Produtos que vendem um item, do menor pacote para o maior.
function Products.forItem(item: Types.ItemId): { Types.ProductDef }
	local list: { Types.ProductDef } = {}
	for _, product in ipairs(Balance.shop.products) do
		if product.item == item then
			table.insert(list, product)
		end
	end
	table.sort(list, function(a, b)
		return a.quantity < b.quantity
	end)
	return list
end

return Products
