--!strict
-- Ações de menu sobre o perfil: equipe, compra de torres, configurações, cosméticos, loja e pendências.
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Protocol = require(Shared.Net.Protocol)
local Products = require(Shared.Config.Products)
local ProfileSchema = require(Shared.Profile.ProfileSchema)
local ProfileService = require(script.Parent.ProfileService)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)
local TelemetryService = require(script.Parent.TelemetryService)

local MenuService = {}

local function result(ok: boolean, code: string?, extra: { [string]: any }?): { [string]: any }
	local r: { [string]: any } = { ok = ok, errorCode = code }
	if extra then
		for k, v in pairs(extra) do
			r[k] = v
		end
	end
	return r
end

local function withProfile(player: Player, fn: (Types.Profile) -> (boolean, string?)): { [string]: any }
	local profile = ProfileService.get(player)
	if not profile then
		return result(false, Protocol.ERROR.PROFILE_UNAVAILABLE)
	end
	local ok, err: string? = true, nil
	local mutated = ProfileService.mutate(player, function(p: Types.Profile)
		ok, err = fn(p)
	end)
	if not mutated then
		return result(false, Protocol.ERROR.PROFILE_UNAVAILABLE)
	end
	if not ok then
		return result(false, err)
	end
	return result(true, nil, { profile = ProfileService.clientView(player) })
end

function MenuService.handle(player: Player, action: string, payload: { [string]: any }): { [string]: any }
	if action == "SetLoadout" then
		return withProfile(player, function(p: Types.Profile)
			return ProfileSchema.setLoadout(p, payload.towerIds, os.time())
		end)
	elseif action == "BuyTower" then
		local r = withProfile(player, function(p: Types.Profile)
			return ProfileSchema.buyTower(p, payload.towerId, os.time())
		end)
		if r.ok then
			TelemetryService.log("tower_bought", { userId = player.UserId, towerId = payload.towerId })
			task.spawn(function()
				ProfileService.save(player, false)
			end)
		end
		return r
	elseif action == "SaveSettings" then
		return withProfile(player, function(p: Types.Profile)
			p.settings = ProfileSchema.sanitizeSettings(payload, p.settings)
			return true, nil
		end)
	elseif action == "EquipCosmetic" then
		return withProfile(player, function(p: Types.Profile)
			local slot = payload.slot
			local id = payload.cosmeticId
			if slot ~= "banner" and slot ~= "title" and not slot:match("^skin_%a+$") then
				return false, Protocol.ERROR.BAD_REQUEST
			end
			if id == "" then
				p.cosmeticLoadout[slot] = nil
				return true, nil
			end
			if table.find(p.cosmeticsOwned, id) == nil then
				return false, Protocol.ERROR.INVALID_STATE
			end
			p.cosmeticLoadout[slot] = id
			return true, nil
		end)
	elseif action == "QueryShop" then
		return result(true, nil, { shop = ShopService.query(player), available = Products.isShopAvailable() })
	elseif action == "PromptFounderPass" then
		local ok, err = ShopService.prompt(player)
		return result(ok, err)
	elseif action == "ClaimPending" then
		if not ProfileService.get(player) then
			return result(false, Protocol.ERROR.PROFILE_UNAVAILABLE)
		end
		RewardService.reconcilePending(player)
		return result(true, nil, { profile = ProfileService.clientView(player) })
	elseif action == "RetryProfile" then
		ProfileService.retryLoad(player)
		return result(true)
	end
	return result(false, Protocol.ERROR.BAD_REQUEST)
end

return MenuService
