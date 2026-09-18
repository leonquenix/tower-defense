--!strict
-- 08_cosmeticos: domínio e aparência, sem alterar nenhum atributo.
--
-- Contrato:
--  * marcos de domínio: 30 adesivo, 100 título, 250 aparência — o progresso e o requisito ficam visíveis;
--  * Equipar confirma um item já possuído e é idempotente; item bloqueado não envia comando de concessão;
--  * skins mantêm atributos, silhueta e Circuitos;
--  * mudança de aparência no menu vale para a próxima partida (o snapshot da partida em curso não muda);
--  * aparência sem arte final ou sem ID aprovado aparece como "em produção", nunca como produto acabado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local Store = require(script.Parent.Parent.Store)

local Cosmetics = {}
Cosmetics.__index = Cosmetics

local L = Localization.get

export type Callbacks = { onBack: () -> (), onShop: () -> () }

export type Cosmetics = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		content: ScrollingFrame,
		buttons: { Components.Button },
		towerId: string,
		shopEnabled: boolean,
	},
	Cosmetics
))

-- Nenhuma arte de skin foi produzida nesta versão: o catálogo declara o item, mas o asset ainda
-- não existe. A tela mostra isso explicitamente em vez de oferecer um produto inexistente.
local function hasFinalArt(cosmeticId: string): boolean
	return Assets.get("cosmetic_" .. cosmeticId) ~= nil
end

function Cosmetics.new(parent: Instance, callbacks: Callbacks): Cosmetics
	local self = setmetatable({
		callbacks = callbacks,
		buttons = {},
		towerId = "dardo",
		shopEnabled = false,
	}, Cosmetics) :: any
	self.chrome = Chrome.new(parent, {
		name = "CosmeticsScreen",
		title = L("cosmetics.title"),
		subtitle = L("cosmetics.subtitle"),
		onBack = callbacks.onBack,
	})
	self.content = Components.scroller(self.chrome.body, "Content", { ZIndex = 2 })
	local layout = Components.list(self.content, Enum.FillDirection.Vertical, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return self
end

function Cosmetics.setTower(self: Cosmetics, towerId: string)
	self.towerId = towerId
end

function Cosmetics.setShopEnabled(self: Cosmetics, enabled: boolean)
	self.shopEnabled = enabled
end

local function equip(self: Cosmetics, slot: string, cosmeticId: string, button: Components.Button)
	button:setPending(true)
	CommandAdapter.send("profile:cosmetic:" .. slot, "EquipCosmetic", { slot = slot, cosmeticId = cosmeticId }, {
		onSuccess = function(response)
			button:setPending(false)
			if response.profile then
				Store.setProfile(response.profile)
			end
			button:flashSuccess(L("cosmetics.equipped"))
			Cosmetics.render(self)
		end,
		onError = function(code)
			button:setPending(false)
			button:showError(if Localization.has("error." .. code) then L("error." .. code) else L("common.retry"))
		end,
	})
end

function Cosmetics.render(self: Cosmetics)
	self.chrome:refreshBalance()
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	for _, child in ipairs(self.content:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local def = Catalog.getTower(self.towerId)
	if not def then
		Components.emptyState(self.content, "Unknown", L("detail.unknownTower"), {
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 1,
		})
		return
	end
	self.chrome:setTitle(L("cosmetics.titleFor", { tower = def.name }), L("cosmetics.subtitle"))

	local profile = Store.profile()
	local owned: { string } = if profile then (profile.cosmeticsOwned or {}) else {}
	local equipped: { [string]: any } = if profile then (profile.cosmeticLoadout or {}) else {}
	local points = 0
	if profile and profile.masteryByTower and profile.masteryByTower[def.id] then
		points = profile.masteryByTower[def.id].points or 0
	end

	-- progresso de domínio
	local header = Components.panel(self.content, "Mastery", {
		Size = UDim2.new(1, 0, 0, 96),
		LayoutOrder = 1,
		ZIndex = 3,
	}, { tape = true, shadow = false })
	Components.padding(header, 16, 14)
	Components.label(header, "Title", L("collection.mastery", { points = points }), {
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.bodyLarge,
		ZIndex = 4,
	})
	local milestones = Balance.rewards.masteryMilestones
	local last = milestones[#milestones]
	local bar = Components.progressBar(header, "Bar", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 32),
		ZIndex = 4,
	}, Theme.colors.teal)
	bar:setProgress(points / math.max(last, 1), false)
	Components.stroke(bar.instance, Theme.colors.ink, 2)
	local marks = {}
	for _, milestone in ipairs(milestones) do
		table.insert(
			marks,
			string.format("%d %s", milestone, L("cosmetics.milestone." .. tostring(milestone)))
				.. (if points >= milestone then " ✓" else "")
		)
	end
	Components.caption(header, "Marks", table.concat(marks, "   ·   "), {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 50),
		TextWrapped = false,
		ZIndex = 4,
	})
	Components.caption(header, "NoStats", L("cosmetics.noStats"), {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 70),
		ZIndex = 4,
	})

	-- itens por marco
	local byMilestone = Products.masteryCosmetics(def.id)
	local order = 2
	for _, milestone in ipairs(milestones) do
		local cosmetic = byMilestone[milestone]
		if cosmetic then
			local unlocked = points >= milestone
			local isOwned = table.find(owned, cosmetic.id) ~= nil
			local slot = if cosmetic.kind == "skin" then "skin_" .. def.id else cosmetic.kind
			local isEquipped = equipped[slot] == cosmetic.id
			local card = Components.panel(self.content, "C_" .. cosmetic.id, {
				Size = UDim2.new(1, 0, 0, 96),
				LayoutOrder = order,
				ZIndex = 3,
			}, { shadow = false })
			Components.padding(card, 16, 14)
			Components.label(card, "Name", L("cosmetics.item." .. cosmetic.kind, { tower = def.name }), {
				Size = UDim2.new(1, -280, 0, 24),
				Font = Theme.fonts.bodyBold,
				TextSize = Theme.sizes.bodyLarge,
				ZIndex = 4,
			})
			local requirement = if unlocked
				then L("cosmetics.unlockedAt", { points = milestone })
				else L("cosmetics.requires", { points = milestone, missing = milestone - points })
			Components.caption(card, "Requirement", requirement, {
				Size = UDim2.new(1, -280, 0, 20),
				Position = UDim2.fromOffset(0, 26),
				TextColor3 = if unlocked then Theme.colors.tealDark else Theme.colors.muted,
				ZIndex = 4,
			})
			local artPending = not hasFinalArt(cosmetic.id)
			if artPending then
				Components.caption(card, "ArtPending", L("cosmetics.artPending"), {
					Size = UDim2.new(1, -280, 0, 20),
					Position = UDim2.fromOffset(0, 48),
					TextColor3 = Theme.colors.coral,
					ZIndex = 4,
				})
			end

			local button: Components.Button
			button = Components.button(card, {
				name = "Equip",
				text = if isEquipped then L("cosmetics.equipped") else L("cosmetics.equip"),
				kind = "primary",
				size = UDim2.fromOffset(260, Theme.sizes.buttonTarget),
				position = UDim2.new(1, -260, 0.5, -24),
				zIndex = 4,
				onActivate = function()
					if isEquipped then
						-- repetir Equipar é idempotente: o comando só é enviado quando muda algo
						button:flashSuccess(L("cosmetics.equipped"))
						return
					end
					equip(self, slot, cosmetic.id, button)
				end,
			})
			button:setSelected(isEquipped)
			if not unlocked then
				-- bloqueado: nenhum comando de concessão é enviado daqui
				button:setAvailable(
					false,
					L("cosmetics.requires", { points = milestone, missing = milestone - points })
				)
			elseif not isOwned then
				button:setAvailable(false, L("cosmetics.notGrantedYet"))
			elseif artPending then
				button:setAvailable(false, L("cosmetics.artPendingShort"))
			end
			table.insert(self.buttons, button)
			order += 1
		end
	end

	-- outras aparências: só aponta para a loja quando ela existe de verdade
	if self.shopEnabled then
		local shop = Components.button(self.content, {
			name = "Shop",
			text = L("cosmetics.otherLooks"),
			kind = "secondary",
			size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			layoutOrder = order,
			zIndex = 3,
			onActivate = self.callbacks.onShop,
		})
		table.insert(self.buttons, shop)
	else
		Components.caption(self.content, "NoShop", L("cosmetics.shopDisabled"), {
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = order,
			ZIndex = 3,
		})
	end
end

function Cosmetics.show(self: Cosmetics, params: { [string]: any }?)
	if params and params.towerId then
		self.towerId = params.towerId
	end
	self.chrome:show()
	Cosmetics.render(self)
end

function Cosmetics.hide(self: Cosmetics)
	self.chrome:hide()
end

return Cosmetics
