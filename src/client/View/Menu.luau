--!strict
-- Menu inicial: Jogar em destaque, Coleção, Treino, Configurações e Loja secundária.
-- Painel de party, salas com vaga, mapa, dificuldade e equipe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Responsive = require(script.Parent.Responsive)

local Menu = {}
Menu.__index = Menu

local L = Localization.get

export type LobbyData = { [string]: any }

export type Callbacks = {
	onStart: (mapId: string, difficulty: string, matchMode: string) -> (),
	onCollection: () -> (),
	onSettings: () -> (),
	onShop: () -> (),
	onCreateParty: () -> (),
	onJoinParty: (partyId: string) -> (),
	onLeaveParty: () -> (),
	onPartyReady: (ready: boolean) -> (),
	onPartySetup: (mapId: string, difficulty: string) -> (),
	onInvite: (userId: number) -> (),
	onKick: (userId: number) -> (),
	onRetryProfile: () -> (),
}

export type Menu = typeof(setmetatable(
	{} :: {
		root: Frame,
		left: Frame,
		right: Frame,
		status: TextLabel,
		callbacks: Callbacks,
		refreshHeader: () -> (),
		compact: boolean,
		lobby: LobbyData?,
		selectedMap: string,
		selectedDifficulty: string,
		buttonsLabel: TextLabel,
	},
	Menu
))

local MAP_ORDER = { "jardim", "oficina", "sotao" }

function Menu.new(parent: GuiObject, callbacks: Callbacks): Menu
	local root = Ui.frame(
		parent,
		"Menu",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.paper, Visible = false }
	)
	local self = setmetatable({
		root = root,
		callbacks = callbacks,
		lobby = nil,
		selectedMap = "jardim",
		selectedDifficulty = "normal",
		compact = Responsive.isCompact(),
	}, Menu) :: any
	Menu.buildChrome(self)
	return self
end

-- Constrói cabeçalho, coluna esquerda e painel direito para o modo de layout atual
function Menu.buildChrome(self: Menu)
	local root = self.root
	for _, name in ipairs({ "Header", "Left", "Right" }) do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local compact = Responsive.isCompact()
	self.compact = compact
	local leftWidth = if compact then 170 else 260
	local headerHeight = if compact then 44 else 70
	-- cabeçalho
	local header = Ui.frame(
		root,
		"Header",
		{ Size = UDim2.new(1, -16, 0, headerHeight), Position = UDim2.new(0, 8, 0, 6), BackgroundTransparency = 1 }
	)
	Ui.title(
		header,
		"Title",
		L("app.title"),
		{ Size = UDim2.new(0.6, 0, 0, if compact then 28 else 40), TextSize = if compact then 24 else 36 }
	)
	local subtitle = Ui.label(header, "Sub", L("app.subtitle"), {
		Size = UDim2.new(0.6, 0, 0, if compact then 14 else 20),
		Position = UDim2.new(0, 0, 0, if compact then 28 else 42),
		TextSize = if compact then 11 else Theme.sizes.body,
		TextColor3 = Theme.colors.muted,
	})
	self.buttonsLabel = Ui.label(header, "Buttons", "", {
		Size = UDim2.new(0.4, 0, 0, if compact then 26 else 40),
		Position = UDim2.new(0.6, 0, 0, if compact then 0 else 4),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.fonts.numbers,
		TextSize = if compact then 18 else 24,
		TextColor3 = Theme.colors.goldDark,
	})
	self.status = Ui.label(header, "Status", "", {
		Size = UDim2.new(0.4, 0, 0, if compact then 14 else 20),
		Position = UDim2.new(0.6, 0, 0, if compact then 26 else 46),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = if compact then 10 else 13,
		TextColor3 = Theme.colors.danger,
	})
	-- coluna esquerda (rolável em telas baixas)
	local left = Instance.new("ScrollingFrame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.BorderSizePixel = 0
	left.Size = UDim2.new(0, leftWidth, 1, -(headerHeight + 20))
	left.Position = UDim2.new(0, 8, 0, headerHeight + 12)
	left.CanvasSize = UDim2.new()
	left.AutomaticCanvasSize = Enum.AutomaticSize.Y
	left.ScrollBarThickness = 4
	left.Parent = root
	local leftList = Ui.list(left, Enum.FillDirection.Vertical, if compact then 6 else 10)
	leftList.VerticalAlignment = Enum.VerticalAlignment.Top
	self.left = left :: any
	-- painel direito
	local right = Ui.panel(root, "Right", {
		Size = UDim2.new(1, -(leftWidth + 24), 1, -(headerHeight + 20)),
		Position = UDim2.new(0, leftWidth + 16, 0, headerHeight + 12),
		BackgroundColor3 = Theme.colors.cream,
	})
	Ui.padding(right, if compact then 10 else 16)
	self.right = right
	self.refreshHeader = function()
		subtitle.Text = L("app.subtitle")
	end
end

-- Reconstrói o menu quando o modo de layout muda com o redimensionamento da janela
function Menu.relayout(self: Menu)
	if Responsive.isCompact() ~= self.compact then
		Menu.buildChrome(self)
		if self.root.Visible then
			Menu.render(self)
		end
	end
end

local function clear(frame: Frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function profileOf(lobby: LobbyData?): { [string]: any }?
	if lobby and lobby.profile and (lobby.profile.status == "ready" or lobby.profile.status == "volatile") then
		return lobby.profile
	end
	return nil
end

local function isUnlocked(profile: { [string]: any }?, mapId: string, difficulty: string): boolean
	if not profile then
		return false
	end
	if mapId == "jardim" and difficulty == "normal" then
		return profile.tutorialCompleted == true or (profile.mapUnlocks and profile.mapUnlocks["jardim:normal"] == true)
	end
	return profile.mapUnlocks ~= nil and profile.mapUnlocks[mapId .. ":" .. difficulty] == true
end

function Menu.render(self: Menu)
	self.refreshHeader()
	local lobby = self.lobby
	local profile = profileOf(lobby)
	local party = if lobby then lobby.party else nil
	local isLeader = party ~= nil and party.leaderId == Players.LocalPlayer.UserId
	local inParty = party ~= nil and #party.members > 1
	if party then
		-- o grupo compartilha mapa e dificuldade definidos pelo líder
		self.selectedMap = party.mapId
		self.selectedDifficulty = party.difficulty
	end
	-- cabeçalho
	if profile then
		self.buttonsLabel.Text = Ui.formatNumber(profile.buttons) .. " " .. L("common.buttons")
		self.status.Text = if profile.persistent then "" else L("app.progressNotSaved")
	else
		self.buttonsLabel.Text = ""
		local st = if lobby and lobby.profile then lobby.profile.status else "loading"
		self.status.Text = if st == "loading" then L("app.loading") else L("app.profileUnavailable")
	end

	-- coluna esquerda
	clear(self.left)
	local order = 0
	local compact = self.compact
	local function add(b: Ui.Button)
		order += 1
		b.instance.LayoutOrder = order
		b.instance.Size = UDim2.new(1, -8, 0, if compact then 44 else 58)
		if compact then
			b.label.TextSize = 15
			b.sub.TextSize = 10
		end
	end
	local play = Ui.button(self.left, "Play", L("menu.play"), "primary")
	play.label.TextSize = 24
	add(play)
	if compact then
		play.label.TextSize = 18
	end
	play:onClick(function()
		if not profile then
			self.callbacks.onRetryProfile()
			return
		end
		if not profile.tutorialCompleted then
			self.callbacks.onStart("jardim", "normal", "tutorial")
		else
			self.callbacks.onStart(self.selectedMap, self.selectedDifficulty, "normal")
		end
	end)
	if profile and not profile.tutorialCompleted then
		play:setText(L("menu.tutorial"), L("menu.startTutorialHint"))
		play.sub.TextWrapped = true
	elseif profile then
		play:setText(
			L("menu.play"),
			if inParty then (if isLeader then L("menu.start") else L("menu.waitingLeader")) else L("menu.solo")
		)
		if inParty and not isLeader then
			play:setEnabled(false, L("menu.waitingLeader"))
		end
	else
		play:setEnabled(false, L("common.retry"))
	end
	local collection = Ui.button(self.left, "Collection", L("menu.collection"), "secondary")
	add(collection)
	collection:onClick(self.callbacks.onCollection)
	local training = Ui.button(self.left, "Training", L("menu.training"), "secondary")
	add(training)
	training:onClick(function()
		self.callbacks.onStart(self.selectedMap, "normal", "training")
	end)
	if profile and profile.tutorialCompleted then
		local tut = Ui.button(self.left, "Tutorial", L("menu.replayTutorial"), "ghost")
		add(tut)
		tut:onClick(function()
			self.callbacks.onStart("jardim", "normal", "tutorial")
		end)
	end
	local settings = Ui.button(self.left, "Settings", L("menu.settings"), "secondary")
	add(settings)
	settings:onClick(self.callbacks.onSettings)
	local shop = Ui.button(self.left, "Shop", L("menu.shop"), "ghost")
	add(shop)
	shop.instance.Size = UDim2.new(1, -8, 0, if compact then 36 else 44)
	shop:onClick(self.callbacks.onShop)
	if
		lobby
		and lobby.profile
		and lobby.profile.status ~= "ready"
		and lobby.profile.status ~= "volatile"
		and lobby.profile.status ~= "loading"
	then
		local retry = Ui.button(self.left, "Retry", L("common.retry"), "danger")
		add(retry)
		retry.instance.Size = UDim2.new(1, -8, 0, 44)
		retry:onClick(self.callbacks.onRetryProfile)
	end

	-- painel direito
	clear(self.right)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = self.right
	local list = Ui.list(scroll, Enum.FillDirection.Vertical, 12)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	local o = 0
	local function next_(inst: GuiObject)
		o += 1
		inst.LayoutOrder = o
		inst.Parent = scroll
	end

	-- mapa e dificuldade
	local mapTitle = Ui.label(nil, "MapTitle", Ui.upper(L("menu.map")), {
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 12,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
	})
	next_(mapTitle)
	local mapRow =
		Ui.frame(nil, "MapRow", { Size = UDim2.new(1, 0, 0, if compact then 78 else 96), BackgroundTransparency = 1 })
	mapRow.AutomaticSize = Enum.AutomaticSize.Y
	local mapList = Ui.list(mapRow, Enum.FillDirection.Horizontal, 10)
	mapList.Wraps = true
	mapList.VerticalAlignment = Enum.VerticalAlignment.Top
	next_(mapRow)
	local canConfigure = not inParty or isLeader
	for i, mapId in ipairs(MAP_ORDER) do
		local map = Catalog.getMap(mapId) :: any
		local unlocked = isUnlocked(profile, mapId, self.selectedDifficulty)
		local card = Ui.button(
			mapRow,
			"Map_" .. mapId,
			map.name,
			if self.selectedMap == mapId then "primary" else "secondary",
			{ Size = UDim2.new(0, if compact then 150 else 190, 0, if compact then 78 else 96), LayoutOrder = i }
		)
		local ground = Assets.get(Assets.groundKey(mapId))
		if ground and ground.image then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = ground.image :: string
			img.Size = UDim2.new(1, -12, 0, 44)
			img.Position = UDim2.new(0, 6, 0, 6)
			img.ScaleType = Enum.ScaleType.Crop
			img.ZIndex = card.instance.ZIndex + 1
			img.Parent = card.instance
			Ui.corner(img, 8)
			card.label.Position = UDim2.new(0, 8, 0, 26)
		end
		if not unlocked then
			local reason = if mapId == "jardim"
				then L("menu.lockedTutorial")
				elseif self.selectedDifficulty == "desafio" then L("menu.lockedDesafio")
				else L(
					"menu.lockedMap",
					{ map = (Catalog.getMap(if mapId == "oficina" then "jardim" else "oficina") :: any).name }
				)
			card:setEnabled(false, "🔒 " .. reason)
			card.sub.TextWrapped = true
			card.sub.TextSize = 11
			card.sub.Size = UDim2.new(1, -12, 0, 30)
			card.sub.Position = UDim2.new(0, 6, 1, -32)
			card.label.Position = UDim2.new(0, 8, 0, 14)
		end
		card:onClick(function()
			if not canConfigure then
				return
			end
			self.selectedMap = mapId
			if party then
				self.callbacks.onPartySetup(mapId, self.selectedDifficulty)
			end
			Menu.render(self)
		end)
	end
	local diffRow = Ui.frame(nil, "DiffRow", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 })
	Ui.list(diffRow, Enum.FillDirection.Horizontal, 10)
	next_(diffRow)
	Ui.label(
		diffRow,
		"DiffTitle",
		L("menu.difficulty"),
		{ Size = UDim2.new(0, 110, 1, 0), Font = Theme.fonts.bodyBold, LayoutOrder = 0 }
	)
	for i, diff in ipairs({ "normal", "desafio" }) do
		local b = Ui.button(
			diffRow,
			"Diff_" .. diff,
			L("menu.difficulty." .. diff),
			if self.selectedDifficulty == diff then "primary" else "secondary",
			{ Size = UDim2.new(0, 150, 0, 44), LayoutOrder = i }
		)
		if diff == "desafio" and not isUnlocked(profile, self.selectedMap, "desafio") then
			b:setEnabled(false, "🔒 " .. L("menu.lockedDesafio"))
		end
		b:onClick(function()
			if not canConfigure then
				return
			end
			self.selectedDifficulty = diff
			if party then
				self.callbacks.onPartySetup(self.selectedMap, diff)
			end
			Menu.render(self)
		end)
	end

	-- equipe
	next_(Ui.label(nil, "TeamTitle", Ui.upper(L("menu.team")), {
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 12,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
	}))
	local teamRow =
		Ui.frame(nil, "TeamRow", { Size = UDim2.new(1, 0, 0, if compact then 76 else 92), BackgroundTransparency = 1 })
	teamRow.AutomaticSize = Enum.AutomaticSize.Y
	local teamList = Ui.list(teamRow, Enum.FillDirection.Horizontal, 10)
	teamList.Wraps = true
	teamList.VerticalAlignment = Enum.VerticalAlignment.Top
	next_(teamRow)
	local loadout: { string } = if profile then profile.loadout else Catalog.starterTowerIds()
	for slot = 1, Balance.loadoutSlots do
		local towerId = loadout[slot]
		local card = Ui.panel(teamRow, "Slot" .. slot, {
			Size = UDim2.new(0, if compact then 96 else 120, 0, if compact then 76 else 92),
			LayoutOrder = slot,
			BackgroundColor3 = if towerId then Theme.colors.cream else Theme.colors.paper,
		})
		if towerId then
			local def = Catalog.getTower(towerId) :: Types.TowerDef
			local entry = Assets.get(Assets.towerKey(towerId, "L0"))
			if entry and (entry.portrait or entry.image) then
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = (entry.portrait or entry.image) :: string
				img.Size = UDim2.new(0, 56, 0, 56)
				img.Position = UDim2.new(0.5, 0, 0, 4)
				img.AnchorPoint = Vector2.new(0.5, 0)
				img.ScaleType = Enum.ScaleType.Fit
				img.Parent = card
			end
			Ui.label(card, "Name", def.name, {
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 1, -24),
				TextXAlignment = Enum.TextXAlignment.Center,
				Font = Theme.fonts.bodyBold,
			})
		else
			Ui.label(card, "Empty", "—", {
				Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Theme.colors.muted,
				TextSize = 24,
			})
		end
	end
	local teamHint = L("menu.teamHint")
	if profile and #profile.ownedTowerIds == 3 then
		local lupa = Catalog.getTower("lupa")
		if lupa then
			teamHint ..= " " .. L("menu.suggestLupa", { cost = lupa.unlock })
		end
	end
	next_(
		Ui.label(
			nil,
			"TeamHint",
			teamHint,
			{ Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextColor3 = Theme.colors.muted }
		)
	)

	-- party
	next_(Ui.label(nil, "PartyTitle", Ui.upper(L("menu.members")), {
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 12,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
	}))
	local partyBox = Ui.frame(
		nil,
		"PartyBox",
		{ Size = UDim2.new(1, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }
	)
	Ui.list(partyBox, Enum.FillDirection.Vertical, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	next_(partyBox)
	if party then
		local leaderName = "?"
		for _, m in ipairs(party.members) do
			if m.userId == party.leaderId then
				leaderName = m.name
			end
		end
		Ui.label(
			partyBox,
			"PartyName",
			L("menu.partyOf", { leader = leaderName }) .. "  ·  " .. #party.members .. "/" .. Balance.partyMax,
			{ Size = UDim2.new(1, 0, 0, 22), Font = Theme.fonts.bodyBold, LayoutOrder = 0 }
		)
		for i, m in ipairs(party.members) do
			local row = Ui.frame(
				partyBox,
				"M" .. m.userId,
				{ Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = i }
			)
			local owner = Theme.owners[((i - 1) % 4) + 1]
			local statusText = if m.userId == party.leaderId
				then "👑"
				elseif m.ready then "✓ " .. L("common.ready")
				else L("common.notReady")
			Ui.label(
				row,
				"Name",
				owner.glyph .. " " .. m.name .. "  ·  " .. statusText .. (if not m.unlocked then "  ·  🔒" else ""),
				{
					Size = UDim2.new(1, -110, 1, 0),
					TextColor3 = if m.unlocked then Theme.colors.ink else Theme.colors.danger,
				}
			)
			if isLeader and m.userId ~= Players.LocalPlayer.UserId then
				local kick = Ui.button(
					row,
					"Kick",
					L("menu.kick"),
					"ghost",
					{ Size = UDim2.new(0, 100, 0, 36), Position = UDim2.new(1, -100, 0, 2) }
				)
				kick.label.TextSize = 13
				kick:onClick(function()
					self.callbacks.onKick(m.userId)
				end)
			end
		end
		local actions = Ui.frame(
			partyBox,
			"Actions",
			{ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 99 }
		)
		Ui.list(actions, Enum.FillDirection.Horizontal, 8)
		if not isLeader then
			local me: any = nil
			for _, m in ipairs(party.members) do
				if m.userId == Players.LocalPlayer.UserId then
					me = m
				end
			end
			local ready = Ui.button(
				actions,
				"Ready",
				if me and me.ready then "✓ " .. L("common.ready") else L("common.ready"),
				if me and me.ready then "secondary" else "primary",
				{ Size = UDim2.new(0, 150, 0, 44) }
			)
			ready:onClick(function()
				self.callbacks.onPartyReady(not (me and me.ready))
			end)
		end
		local leave = Ui.button(actions, "Leave", L("menu.leaveParty"), "danger", { Size = UDim2.new(0, 160, 0, 44) })
		leave:onClick(self.callbacks.onLeaveParty)
	else
		local create = Ui.button(
			partyBox,
			"Create",
			L("menu.createParty"),
			"secondary",
			{ Size = UDim2.new(0, 200, 0, 44), LayoutOrder = 0 }
		)
		create:onClick(self.callbacks.onCreateParty)
	end
	-- jogadores presentes para convite
	if lobby and lobby.players and #lobby.players > 1 then
		local invRow = Ui.frame(partyBox, "Invites", {
			Size = UDim2.new(1, 0, 0, 10),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 100,
		})
		Ui.list(invRow, Enum.FillDirection.Vertical, 4).VerticalAlignment = Enum.VerticalAlignment.Top
		Ui.label(
			invRow,
			"T",
			L("menu.invite"),
			{ Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = Theme.colors.muted, LayoutOrder = 0 }
		)
		for i, p in ipairs(lobby.players) do
			if p.userId ~= Players.LocalPlayer.UserId and not p.inMatch and not p.inParty then
				local b = Ui.button(
					invRow,
					"Inv" .. p.userId,
					L("menu.invite") .. ": " .. p.name,
					"ghost",
					{ Size = UDim2.new(0, 260, 0, 40), LayoutOrder = i }
				)
				b.label.TextSize = 14
				b:onClick(function()
					self.callbacks.onInvite(p.userId)
				end)
			end
		end
	end
	-- salas
	next_(Ui.label(nil, "RoomsTitle", Ui.upper(L("menu.openRooms")), {
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 12,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.tealDark,
	}))
	local rooms = if lobby then lobby.rooms else nil
	if not rooms or #rooms == 0 then
		next_(
			Ui.label(
				nil,
				"NoRooms",
				L("menu.noRooms"),
				{ Size = UDim2.new(1, 0, 0, 36), TextSize = 13, TextColor3 = Theme.colors.muted }
			)
		)
	else
		for i, room in ipairs(rooms) do
			if not party or room.id ~= party.id then
				local b = Ui.button(
					nil,
					"Room" .. room.id,
					L("menu.partyOf", { leader = room.leaderName })
						.. "  ·  "
						.. room.size
						.. "/"
						.. Balance.partyMax
						.. "  ·  "
						.. (Catalog.getMap(room.mapId) :: any).name
						.. " · "
						.. L("menu.difficulty." .. room.difficulty),
					"secondary",
					{ Size = UDim2.new(1, 0, 0, 44) }
				)
				b.label.TextSize = 14
				b.label.TextXAlignment = Enum.TextXAlignment.Left
				b:setText(b.label.Text, L("menu.joinParty"))
				next_(b.instance)
				b:onClick(function()
					self.callbacks.onJoinParty(room.id)
				end)
			end
		end
	end
	if lobby and lobby.inMatch then
		next_(
			Ui.label(
				nil,
				"InMatch",
				L("menu.matchInProgress"),
				{ Size = UDim2.new(1, 0, 0, 24), TextColor3 = Theme.colors.danger }
			)
		)
	end
end

function Menu.setLobby(self: Menu, lobby: LobbyData)
	self.lobby = lobby
	if self.root.Visible then
		Menu.render(self)
	end
end

function Menu.show(self: Menu)
	self.root.Visible = true
	Menu.render(self)
end

function Menu.hide(self: Menu)
	self.root.Visible = false
end

function Menu.lobbyData(self: Menu): LobbyData?
	return self.lobby
end

return Menu
