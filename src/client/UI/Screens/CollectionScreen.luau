--!strict
-- 06_colecao, 43_colecao_estados e 47_mobile_colecao: escolher até quatro torres diferentes.
--
-- Contrato:
--  * tocar no personagem abre o detalhe (07); Equipar ocupa o primeiro espaço vazio;
--  * com quatro preenchidos, Equipar pergunta qual substituir (modal da prancha 38);
--  * tocar num espaço equipado permite remover; a equipe não precisa estar cheia;
--  * seleções são locais até Salvar confirmar — "Confirmando…" e depois "Equipe salva";
--  * até quatro IDs distintos e possuídos; duplicata e torre bloqueada são recusadas;
--  * em partida, a coleção é leitura: o loadout da largada fica congelado;
--  * no celular, lista paginada com Próximo/Anterior e equipe + Salvar fixos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Responsive = require(script.Parent.Parent.Parent.View.Responsive)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local Modal = require(script.Parent.Parent.Modal)
local Store = require(script.Parent.Parent.Store)

local CollectionScreen = {}
CollectionScreen.__index = CollectionScreen

local L = Localization.get

local PAGE_SIZE = 4 -- cartas por página no layout compacto (prancha 47)

export type Callbacks = {
	onBack: () -> (),
	onOpenTower: (towerId: string) -> (),
	onSaved: () -> (),
}

export type CollectionScreen = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		grid: ScrollingFrame,
		teamRow: Frame,
		footer: Frame,
		buttons: { Components.Button },
		draft: { string },
		pageIndex: number,
		readOnly: boolean,
		saveButton: Components.Button?,
	},
	CollectionScreen
))

local function ownedIds(profile: { [string]: any }?): { string }
	if profile and profile.ownedTowerIds then
		return profile.ownedTowerIds
	end
	return Catalog.starterTowerIds()
end

local function masteryPoints(profile: { [string]: any }?, towerId: string): number
	if profile and profile.masteryByTower and profile.masteryByTower[towerId] then
		return profile.masteryByTower[towerId].points or 0
	end
	return 0
end

function CollectionScreen.new(parent: Instance, callbacks: Callbacks): CollectionScreen
	local self = setmetatable({
		callbacks = callbacks,
		buttons = {},
		draft = {},
		pageIndex = 1,
		readOnly = false,
	}, CollectionScreen) :: any
	self.chrome = Chrome.new(parent, {
		name = "CollectionScreen",
		title = L("collection.title"),
		subtitle = L("collection.subtitle"),
		onBack = callbacks.onBack,
	})
	local body = self.chrome.body
	local footerHeight = Theme.sizes.buttonTarget + 12
	local teamHeight = 108
	self.grid = Components.scroller(body, "Grid", {
		Size = UDim2.new(1, 0, 1, -(teamHeight + footerHeight + 16)),
		ZIndex = 2,
	})
	self.teamRow = Components.frame(body, "Team", {
		Size = UDim2.new(1, 0, 0, teamHeight),
		Position = UDim2.new(0, 0, 1, -(teamHeight + footerHeight + 8)),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	self.footer = Components.frame(body, "Footer", {
		Size = UDim2.new(1, 0, 0, footerHeight),
		Position = UDim2.new(0, 0, 1, -footerHeight),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	Components.list(self.footer, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	return self
end

-- A equipe local só vira equipe real depois do ACK de SetLoadout.
function CollectionScreen.resetDraft(self: CollectionScreen)
	local profile = Store.profile()
	self.draft = if profile and profile.loadout then table.clone(profile.loadout) else Catalog.starterTowerIds()
end

local function draftChanged(self: CollectionScreen): boolean
	local profile = Store.profile()
	local saved: { string } = if profile and profile.loadout then profile.loadout else {}
	if #saved ~= #self.draft then
		return true
	end
	for index, id in ipairs(saved) do
		if self.draft[index] ~= id then
			return true
		end
	end
	return false
end

local function equip(self: CollectionScreen, towerId: string)
	if table.find(self.draft, towerId) then
		return -- duplicata recusada na origem
	end
	if #self.draft < Balance.loadoutSlots then
		table.insert(self.draft, towerId)
		CollectionScreen.render(self)
		return
	end
	-- equipe cheia: escolher qual substituir antes do botão Trocar (prancha 38)
	local chosenSlot: number? = nil
	local slotButtons: { Components.Button } = {}
	local def = Catalog.getTower(towerId)
	Modal.open(self.chrome.root, {
		title = L("collection.replaceTitle"),
		body = L("collection.replaceBody", { tower = if def then def.name else towerId }),
		confirmText = L("collection.replaceConfirm", { tower = if def then def.name else towerId }),
		width = 520,
		build = function(content, controls)
			for slot, currentId in ipairs(self.draft) do
				local currentDef = Catalog.getTower(currentId)
				local button: Components.Button
				button = Components.button(content, {
					name = "Slot" .. slot,
					text = L("collection.slotOf", {
						slot = slot,
						tower = if currentDef then currentDef.name else currentId,
					}),
					kind = "secondary",
					size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
					layoutOrder = slot,
					textAlign = Enum.TextXAlignment.Left,
					zIndex = 5,
					onActivate = function()
						chosenSlot = slot
						for index, other in ipairs(slotButtons) do
							other:setSelected(index == slot)
						end
						controls:setError(nil)
					end,
				})
				table.insert(slotButtons, button)
			end
		end,
		onConfirm = function(controls)
			if not chosenSlot then
				controls:setError(L("collection.pickSlotFirst"))
				return
			end
			self.draft[chosenSlot :: number] = towerId
			controls:close()
			for _, button in ipairs(slotButtons) do
				button:destroy()
			end
			CollectionScreen.render(self)
		end,
		onCancel = function()
			for _, button in ipairs(slotButtons) do
				button:destroy()
			end
		end,
	})
end

local function unequip(self: CollectionScreen, towerId: string)
	local index = table.find(self.draft, towerId)
	if index then
		table.remove(self.draft, index)
		CollectionScreen.render(self)
	end
end

local function towerCard(
	self: CollectionScreen,
	parent: Instance,
	def: Types.TowerDef,
	order: number,
	size: UDim2,
	profile: { [string]: any }?
)
	local owned = table.find(ownedIds(profile), def.id) ~= nil
	local equipped = table.find(self.draft, def.id) ~= nil
	local card = Components.panel(parent, "Card_" .. def.id, {
		Size = size,
		LayoutOrder = order,
		ZIndex = 3,
	}, { tape = equipped, shadow = false })
	Components.padding(card, 14, 12)

	local entry = Assets.get(Assets.towerKey(def.id, "L0"))
	local portrait = if entry then (entry.portrait or entry.image) else nil
	if portrait then
		local image = Instance.new("ImageLabel")
		image.Name = "Portrait"
		image.BackgroundTransparency = 1
		image.Image = portrait :: string
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromOffset(88, 88)
		image.ImageColor3 = if owned then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		image.Active = false
		image.ZIndex = card.ZIndex + 1
		image.Parent = card
	else
		-- retrato neutro com o nome quando a imagem não carregou (prancha 42)
		local fallback = Components.frame(card, "PortraitFallback", {
			Size = UDim2.fromOffset(88, 88),
			BackgroundColor3 = Theme.colors.sage,
			ZIndex = card.ZIndex + 1,
		})
		Components.corner(fallback, 12)
		Components.label(fallback, "Initial", def.name:sub(1, 1), {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 34,
			Font = Theme.fonts.title,
			TextColor3 = Theme.colors.muted,
			ZIndex = fallback.ZIndex + 1,
		})
	end

	Components.title(card, "Name", def.name, {
		Size = UDim2.new(1, -100, 0, 30),
		Position = UDim2.fromOffset(98, 0),
		TextSize = 24,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = card.ZIndex + 1,
	})
	Components.caption(card, "Role", def.role, {
		Size = UDim2.new(1, -100, 0, 18),
		Position = UDim2.fromOffset(98, 30),
		ZIndex = card.ZIndex + 1,
	})

	local status = if not owned
		then L("collection.locked")
		elseif equipped then L("collection.equipped")
		else L("collection.owned")
	Components.label(card, "Status", status, {
		Size = UDim2.new(1, -100, 0, 20),
		Position = UDim2.fromOffset(98, 50),
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = if not owned then Theme.colors.muted else Theme.colors.tealDark,
		ZIndex = card.ZIndex + 1,
	})

	local stats = def.states.L0
	local costLine = L("collection.buildCost", { cost = stats.cost })
	if not owned then
		costLine = L("collection.unlockCost", { cost = def.unlock }) .. "  ·  " .. costLine
	end
	Components.caption(card, "Cost", costLine, {
		Size = UDim2.new(1, -100, 0, 18),
		Position = UDim2.fromOffset(98, 70),
		TextWrapped = false,
		ZIndex = card.ZIndex + 1,
	})
	Components.caption(card, "Mastery", L("collection.mastery", { points = masteryPoints(profile, def.id) }), {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 94),
		ZIndex = card.ZIndex + 1,
	})

	local row = Components.frame(card, "Row", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
		Position = UDim2.new(0, 0, 1, -Theme.sizes.buttonTarget),
		BackgroundTransparency = 1,
		ZIndex = card.ZIndex + 1,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 8)

	local details = Components.button(row, {
		name = "Details",
		text = L("collection.details"),
		kind = "secondary",
		size = UDim2.new(0.5, -4, 0, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = card.ZIndex + 2,
		onActivate = function()
			self.callbacks.onOpenTower(def.id)
		end,
	})
	table.insert(self.buttons, details)

	local action: Components.Button
	if not owned then
		action = Components.button(row, {
			name = "Unlock",
			text = L("collection.unlock"),
			kind = "primary",
			size = UDim2.new(0.5, -4, 0, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = card.ZIndex + 2,
			onActivate = function()
				self.callbacks.onOpenTower(def.id)
			end,
		})
		local missing = def.unlock - Store.buttons()
		if missing > 0 then
			-- saldo insuficiente informa o quanto falta e não abre loja de Robux
			action:setAvailable(true, L("collection.notEnough", { missing = missing }))
		end
	elseif equipped then
		action = Components.button(row, {
			name = "Unequip",
			text = L("collection.unequip"),
			kind = "secondary",
			size = UDim2.new(0.5, -4, 0, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = card.ZIndex + 2,
			onActivate = function()
				unequip(self, def.id)
			end,
		})
		action:setSelected(true)
	else
		action = Components.button(row, {
			name = "Equip",
			text = L("collection.equip"),
			kind = "primary",
			size = UDim2.new(0.5, -4, 0, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = card.ZIndex + 2,
			onActivate = function()
				equip(self, def.id)
			end,
		})
	end
	if self.readOnly then
		action:setAvailable(false, L("collection.readOnly"))
	end
	table.insert(self.buttons, action)
end

function CollectionScreen.save(self: CollectionScreen)
	local button = self.saveButton
	if not button then
		return
	end
	if CommandAdapter.isPending("profile:loadout") then
		return
	end
	button:setPending(true)
	CommandAdapter.send("profile:loadout", "SetLoadout", { towerIds = table.clone(self.draft) }, {
		onStage = function(stage)
			if stage == "slow" then
				button:setPending(true, L("common.stillWorking"))
			end
		end,
		onSuccess = function(response)
			button:setPending(false)
			if response.profile then
				Store.setProfile(response.profile)
			end
			CollectionScreen.resetDraft(self)
			button:flashSuccess(L("collection.saved"))
			CollectionScreen.render(self)
			self.callbacks.onSaved()
		end,
		onError = function(code)
			button:setPending(false)
			button:showError(if Localization.has("error." .. code) then L("error." .. code) else L("common.retry"))
		end,
	})
end

function CollectionScreen.render(self: CollectionScreen)
	self.chrome:refreshBalance()
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	local containers: { Instance } = { self.grid, self.teamRow, self.footer }
	for _, frame in ipairs(containers) do
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	self.saveButton = nil

	local compact = Responsive.isCompact()
	local profile = Store.profile()
	local towers = Balance.towers
	local totalPages = math.max(1, math.ceil(#towers / PAGE_SIZE))
	self.pageIndex = math.clamp(self.pageIndex, 1, totalPages)

	if compact then
		-- 47: página com Próximo/Anterior; nenhum personagem depende de gesto para ser alcançado
		local layout = Components.list(self.grid, Enum.FillDirection.Horizontal, 10)
		layout.Wraps = true
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		local first = (self.pageIndex - 1) * PAGE_SIZE + 1
		for offset = 0, PAGE_SIZE - 1 do
			local def = towers[first + offset]
			if def then
				towerCard(self, self.grid, def, offset + 1, UDim2.new(0.5, -5, 0, 210), profile)
			end
		end
		local pager = Components.frame(self.teamRow, "Pager", {
			Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			BackgroundTransparency = 1,
			ZIndex = 4,
		})
		Components.list(pager, Enum.FillDirection.Horizontal, 10)
		table.insert(
			self.buttons,
			Components.button(pager, {
				name = "Previous",
				text = L("collection.previous"),
				kind = "secondary",
				size = UDim2.fromOffset(162, Theme.sizes.buttonTarget),
				layoutOrder = 1,
				zIndex = 5,
				onActivate = function()
					self.pageIndex = ((self.pageIndex - 2) % totalPages) + 1
					CollectionScreen.render(self)
				end,
			})
		)
		table.insert(
			self.buttons,
			Components.button(pager, {
				name = "Next",
				text = L("collection.next"),
				kind = "secondary",
				size = UDim2.fromOffset(162, Theme.sizes.buttonTarget),
				layoutOrder = 2,
				zIndex = 5,
				onActivate = function()
					self.pageIndex = (self.pageIndex % totalPages) + 1
					CollectionScreen.render(self)
				end,
			})
		)
		Components.caption(pager, "Index", L("maps.pager", { index = self.pageIndex, total = totalPages }), {
			Size = UDim2.fromOffset(120, 20),
			LayoutOrder = 3,
			ZIndex = 5,
		})
	else
		local layout = Components.list(self.grid, Enum.FillDirection.Horizontal, 12)
		layout.Wraps = true
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		local width = self.grid.AbsoluteSize.X
		local columns = if width > 980 then 3 else 2
		for index, def in ipairs(towers) do
			towerCard(self, self.grid, def, index, UDim2.new(1 / columns, -12, 0, 220), profile)
		end
	end

	-- faixa da equipe: quatro espaços, sempre visível, com remoção por toque
	local slots = Components.frame(self.teamRow, "Slots", {
		Size = UDim2.new(1, 0, 0, 96),
		Position = UDim2.new(0, 0, 0, if compact then Theme.sizes.buttonTarget + 6 else 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	Components.list(slots, Enum.FillDirection.Horizontal, 10)
	for slot = 1, Balance.loadoutSlots do
		local towerId = self.draft[slot]
		local def = if towerId then Catalog.getTower(towerId) else nil
		local button = Components.button(slots, {
			name = "Slot" .. slot,
			text = if def then def.name else L("collection.freeSlot"),
			sub = if def then L("collection.tapToRemove") else L("collection.optionalSlot"),
			kind = if def then "secondary" else "quiet",
			size = UDim2.fromOffset(if compact then 150 else 190, 84),
			layoutOrder = slot,
			zIndex = 5,
			onActivate = function()
				if towerId then
					unequip(self, towerId)
				end
			end,
		})
		if not def then
			button:setAvailable(true, L("collection.optionalSlot"))
		end
		if self.readOnly then
			button:setAvailable(false, L("collection.readOnly"))
		end
		table.insert(self.buttons, button)
	end

	local save = Components.button(self.footer, {
		name = "Save",
		text = L("collection.save"),
		kind = "primary",
		icon = "ui_check",
		size = UDim2.fromOffset(if compact then 240 else 279, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 5,
		onActivate = function()
			CollectionScreen.save(self)
		end,
	})
	self.saveButton = save
	table.insert(self.buttons, save)
	if self.readOnly then
		save:setAvailable(false, L("collection.readOnly"))
	elseif not profile then
		save:setAvailable(false, L("app.profileUnavailableShort"))
	elseif not draftChanged(self) then
		save:setAvailable(false, L("collection.noChanges"))
	end

	Components.caption(
		self.footer,
		"Hint",
		L("collection.hint", {
			count = #self.draft,
			max = Balance.loadoutSlots,
		}),
		{
			Size = UDim2.new(1, -320, 0, 22),
			LayoutOrder = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		}
	)
end

-- Chamado pelo detalhe da torre: equipa no rascunho e mostra a coleção com a vaga preenchida
-- (ou com a pergunta de qual substituir, quando a equipe já está cheia).
function CollectionScreen.equipFromDetail(self: CollectionScreen, towerId: string)
	if self.readOnly then
		return
	end
	equip(self, towerId)
end

function CollectionScreen.setReadOnly(self: CollectionScreen, value: boolean)
	self.readOnly = value
end

function CollectionScreen.show(self: CollectionScreen)
	self.chrome:show()
	CollectionScreen.resetDraft(self)
	CollectionScreen.render(self)
end

function CollectionScreen.resume(self: CollectionScreen)
	self.chrome:show()
	CollectionScreen.render(self)
end

function CollectionScreen.hide(self: CollectionScreen)
	self.chrome:hide()
end

return CollectionScreen
