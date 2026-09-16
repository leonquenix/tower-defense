--!strict
-- Configuração de loja. A loja fica desativada até existir um passe criado no Creator Hub
-- e o ID ser preenchido aqui (ver docs/MANUAL_ACTIONS.md). Sem ID válido, o botão de compra não aparece.
local Balance = require(script.Parent.Balance)

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

return Products
