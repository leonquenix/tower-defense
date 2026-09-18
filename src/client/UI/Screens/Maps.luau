--!strict
-- 03_mapas e 48_mobile_mapas: escolher missão e entrar solo ou com amigos.
--
-- Contrato:
--  * Normal e Desafio são seleção exclusiva; Desafio só depois de vencer o Normal daquele mapa;
--  * mapa bloqueado continua consultável e mostra a condição em texto;
--  * "Começar" desabilitado explica qual integrante ainda não desbloqueou o mapa;
--  * dados de desbloqueio são do servidor; entrar não custa botões;
--  * no celular, um cartão por vez com anterior/próximo e indicador "1 de 3", sem arrasto obrigatório.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Responsive = require(script.Parent.Parent.Parent.View.Responsive)
local Components = require(script.Parent.Parent.Components)
local Chrome = require(script.Parent.Chrome)
local Store = require(script.Parent.Parent.Store)

local Maps = {}
Maps.__index = Maps

local L = Localization.get

local MAP_ORDER = { "jardim", "oficina", "sotao" }
local DIFFICULTIES = { "normal", "desafio" }

export type Callbacks = {
	onBack: () -> (),
	onSolo: (mapId: string, difficulty: string) -> (),
	onFriends: (mapId: string, difficulty: string) -> (),
	onSelectionChanged: (mapId: string, difficulty: string) -> (),
}

export type Maps = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		selectedMap: string,
		selectedDifficulty: string,
		pageIndex: number,
		buttons: { Components.Button },
		compact: boolean,
		soloButton: Components.Button?,
		friendsButton: Components.Button?,
	},
	Maps
))

local function unlockKey(mapId: string, difficulty: string): string
	return mapId .. ":" .. difficulty
end

local function isUnlocked(profile: { [string]: any }?, mapId: string, difficulty: string): boolean
	if not profile then
		return false
	end
	local unlocks = profile.mapUnlocks
	if mapId == "jardim" and difficulty == "normal" then
		return profile.tutorialCompleted == true or (unlocks ~= nil and unlocks[unlockKey(mapId, difficulty)] == true)
	end
	return unlocks ~= nil and unlocks[unlockKey(mapId, difficulty)] == true
end

-- Texto do requisito de cada bloqueio, sempre em linguagem do jogador.
local function lockReason(mapId: string, difficulty: string): string
	if difficulty == "desafio" then
		return L("menu.lockedDesafio")
	end
	if mapId == "jardim" then
		return L("menu.lockedTutorial")
	end
	local previous = if mapId == "oficina" then "jardim" else "oficina"
	local map = Catalog.getMap(previous)
	return L("menu.lockedMap", { map = if map then map.name else previous })
end

function Maps.new(parent: Instance, callbacks: Callbacks): Maps
	local self = setmetatable({
		callbacks = callbacks,
		selectedMap = "jardim",
		selectedDifficulty = "normal",
		pageIndex = 1,
		buttons = {},
		compact = Responsive.isCompact(),
	}, Maps) :: any
	self.chrome = Chrome.new(parent, {
		name = "MapsScreen",
		title = L("maps.title"),
		subtitle = L("maps.subtitle"),
		onBack = callbacks.onBack,
	})
	return self
end

function Maps.setSelection(self: Maps, mapId: string, difficulty: string)
	self.selectedMap = mapId
	self.selectedDifficulty = difficulty
	local index = table.find(MAP_ORDER, mapId)
	if index then
		self.pageIndex = index
	end
	if self.chrome.root.Visible then
		Maps.render(self)
	end
end

-- Cartão de mapa: imagem do terreno, nome, resumo e estado de bloqueio.
local function mapCard(
	self: Maps,
	parent: Instance,
	mapId: string,
	size: UDim2,
	order: number,
	profile: { [string]: any }?
): Components.Button
	local map = Catalog.getMap(mapId)
	local name = if map then map.name else mapId
	local selected = self.selectedMap == mapId
	local unlocked = isUnlocked(profile, mapId, self.selectedDifficulty)
	local card = Components.button(parent, {
		name = "Map_" .. mapId,
		text = name,
		kind = if selected then "primary" else "secondary",
		size = size,
		layoutOrder = order,
		textAlign = Enum.TextXAlignment.Left,
		textSize = Theme.sizes.bodyLarge,
		zIndex = 3,
		onActivate = function()
			self.selectedMap = mapId
			local index = table.find(MAP_ORDER, mapId)
			if index then
				self.pageIndex = index
			end
			-- trocar de mapa pode invalidar o Desafio: volta ao Normal e explica a condição
			if self.selectedDifficulty == "desafio" and not isUnlocked(profile, mapId, "desafio") then
				self.selectedDifficulty = "normal"
			end
			self.callbacks.onSelectionChanged(self.selectedMap, self.selectedDifficulty)
			Maps.render(self)
		end,
	})
	card.label.Position = UDim2.new(0, 14, 0, -40)
	card.label.Size = UDim2.new(1, -28, 0, 30)
	card.label.TextYAlignment = Enum.TextYAlignment.Bottom

	local ground = Assets.get(Assets.groundKey(mapId))
	if ground and ground.image then
		local image = Instance.new("ImageLabel")
		image.Name = "Ground"
		image.BackgroundTransparency = 1
		image.Image = ground.image :: string
		image.ScaleType = Enum.ScaleType.Crop
		image.Size = UDim2.new(1, -20, 0, 108)
		image.Position = UDim2.fromOffset(10, 10)
		image.ZIndex = card.instance.ZIndex + 1
		image.Active = false
		image.Parent = card.instance
		Components.corner(image, 12)
		Components.stroke(image, Theme.colors.ink, 2)
	else
		-- imagem rejeitada ou ainda não publicada: retrato neutro com o nome, sem bloquear a rota
		local fallback = Components.frame(card.instance, "GroundFallback", {
			Size = UDim2.new(1, -20, 0, 108),
			Position = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Theme.colors.sageDeep,
			ZIndex = card.instance.ZIndex + 1,
		})
		fallback.Active = false
		Components.corner(fallback, 12)
		Components.label(fallback, "Name", name, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.muted,
			ZIndex = fallback.ZIndex + 1,
		})
	end

	if map then
		Components.caption(card.instance, "Boss", L("maps.boss", { name = L("enemy." .. map.boss) }), {
			Size = UDim2.new(1, -28, 0, 18),
			Position = UDim2.new(0, 14, 1, -46),
			ZIndex = card.instance.ZIndex + 1,
		})
	end
	if not unlocked then
		card:setAvailable(false, lockReason(mapId, self.selectedDifficulty))
		card.sub.Size = UDim2.new(1, -28, 0, 32)
		card.sub.Position = UDim2.new(0, 14, 1, -30)
		card.sub.TextWrapped = true
	else
		card:setSelected(selected)
	end
	table.insert(self.buttons, card)
	return card
end

function Maps.render(self: Maps)
	local chrome = self.chrome
	chrome:refreshBalance()
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	chrome:clearBody()

	local compact = Responsive.isCompact()
	self.compact = compact
	local profile = Store.profile()
	local party = Store.party()
	local isLeader = party ~= nil and party.leaderId == Players.LocalPlayer.UserId
	local canConfigure = party == nil or isLeader

	local body = chrome.body
	local cardsHeight = if compact then 170 else 210
	local cardsArea = Components.frame(body, "Cards", {
		Size = UDim2.new(1, 0, 0, cardsHeight),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})

	if compact then
		-- 48: um cartão por vez, com anterior/próximo e indicador; nenhum gesto obrigatório
		local mapId = MAP_ORDER[self.pageIndex]
		mapCard(self, cardsArea, mapId, UDim2.new(1, -200, 1, 0), 1, profile).instance.Position =
			UDim2.fromOffset(96, 0)
		local previous = Components.button(cardsArea, {
			name = "Previous",
			text = "‹",
			kind = "secondary",
			size = UDim2.fromOffset(84, Theme.sizes.buttonTarget),
			position = UDim2.new(0, 0, 0.5, -24),
			zIndex = 3,
			onActivate = function()
				self.pageIndex = ((self.pageIndex - 2) % #MAP_ORDER) + 1
				self.selectedMap = MAP_ORDER[self.pageIndex]
				self.callbacks.onSelectionChanged(self.selectedMap, self.selectedDifficulty)
				Maps.render(self)
			end,
		})
		local nextButton = Components.button(cardsArea, {
			name = "Next",
			text = "›",
			kind = "secondary",
			size = UDim2.fromOffset(84, Theme.sizes.buttonTarget),
			position = UDim2.new(1, -84, 0.5, -24),
			zIndex = 3,
			onActivate = function()
				self.pageIndex = (self.pageIndex % #MAP_ORDER) + 1
				self.selectedMap = MAP_ORDER[self.pageIndex]
				self.callbacks.onSelectionChanged(self.selectedMap, self.selectedDifficulty)
				Maps.render(self)
			end,
		})
		previous:setAvailable(canConfigure, if canConfigure then nil else L("menu.leaderOnly"))
		nextButton:setAvailable(canConfigure, if canConfigure then nil else L("menu.leaderOnly"))
		table.insert(self.buttons, previous)
		table.insert(self.buttons, nextButton)
		Components.caption(cardsArea, "Pager", L("maps.pager", { index = self.pageIndex, total = #MAP_ORDER }), {
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 1, -18),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
		})
	else
		local layout = Components.list(cardsArea, Enum.FillDirection.Horizontal, 14)
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		for index, mapId in ipairs(MAP_ORDER) do
			mapCard(self, cardsArea, mapId, UDim2.new(1 / 3, -10, 1, 0), index, profile)
		end
	end

	-- dificuldade: seleção exclusiva
	local diffRow = Components.frame(body, "Difficulty", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 8),
		Position = UDim2.new(0, 0, 0, cardsHeight + 14),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	Components.list(diffRow, Enum.FillDirection.Horizontal, 10)
	Components.label(diffRow, "Caption", L("menu.difficulty"), {
		Size = UDim2.fromOffset(120, 24),
		Font = Theme.fonts.bodyBold,
		TextWrapped = false,
		LayoutOrder = 1,
		ZIndex = 3,
	})
	for index, difficulty in ipairs(DIFFICULTIES) do
		local unlocked = isUnlocked(profile, self.selectedMap, difficulty)
		local button = Components.button(diffRow, {
			name = "Diff_" .. difficulty,
			text = L("menu.difficulty." .. difficulty),
			kind = if self.selectedDifficulty == difficulty then "primary" else "secondary",
			size = UDim2.fromOffset(if compact then 160 else 185, Theme.sizes.buttonTarget),
			layoutOrder = index + 1,
			zIndex = 3,
			onActivate = function()
				self.selectedDifficulty = difficulty
				self.callbacks.onSelectionChanged(self.selectedMap, difficulty)
				Maps.render(self)
			end,
		})
		button:setSelected(self.selectedDifficulty == difficulty)
		if not unlocked then
			button:setAvailable(false, lockReason(self.selectedMap, difficulty))
		elseif not canConfigure then
			button:setAvailable(false, L("menu.leaderOnly"))
		end
		table.insert(self.buttons, button)
	end

	-- ações: solo e cooperação
	local actions = Components.frame(body, "Actions", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 8),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget + 8)),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	Components.list(actions, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)

	local ready = isUnlocked(profile, self.selectedMap, self.selectedDifficulty)
	local blockedMember: string? = nil
	if party then
		for _, member in ipairs(party.members) do
			if not member.unlocked then
				blockedMember = member.name
				break
			end
		end
	end

	local friends = Components.button(actions, {
		name = "Friends",
		text = L("maps.friends"),
		kind = "secondary",
		icon = "ui_group",
		size = UDim2.fromOffset(if compact then 230 else 280, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 3,
		onActivate = function()
			self.callbacks.onFriends(self.selectedMap, self.selectedDifficulty)
		end,
	})
	local solo = Components.button(actions, {
		name = "Solo",
		text = L("maps.solo"),
		kind = "primary",
		icon = "ui_play",
		size = UDim2.fromOffset(if compact then 200 else 254, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 3,
		onActivate = function()
			self.callbacks.onSolo(self.selectedMap, self.selectedDifficulty)
		end,
	})
	if not profile then
		solo:setAvailable(false, L("app.profileUnavailableShort"))
		friends:setAvailable(false, L("app.profileUnavailableShort"))
	elseif not ready then
		solo:setAvailable(false, lockReason(self.selectedMap, self.selectedDifficulty))
	elseif blockedMember then
		-- explica QUAL integrante ainda não desbloqueou, não um "indisponível" genérico
		solo:setAvailable(false, L("maps.memberLocked", { name = blockedMember }))
	end
	table.insert(self.buttons, solo)
	table.insert(self.buttons, friends)
	self.soloButton = solo
	self.friendsButton = friends
end

function Maps.show(self: Maps)
	self.chrome:show()
	Maps.render(self)
end

function Maps.hide(self: Maps)
	self.chrome:hide()
end

function Maps.selection(self: Maps): (string, string)
	return self.selectedMap, self.selectedDifficulty
end

return Maps
