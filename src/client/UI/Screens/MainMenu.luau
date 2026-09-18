--!strict
-- 02_inicio e 35_mobile_menu: menu inicial com uma única ação principal.
--
-- Contrato:
--  * Jogar é a única ação dourada dominante e é encontrável em segundos, sem hover obrigatório;
--  * Loja só existe com feature flag e produto válido — desativada, o espaço dela some;
--  * nada de missões diárias, gacha ou popup de compra;
--  * saldo de botões vem do perfil e fica separado da faixa de ações;
--  * a arte decorativa encolhe (e some com texto ampliado) sem levar nenhuma informação vital.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Responsive = require(script.Parent.Parent.Parent.View.Responsive)
local Accessibility = require(script.Parent.Parent.Accessibility)
local Components = require(script.Parent.Parent.Components)
local Store = require(script.Parent.Parent.Store)

local MainMenu = {}
MainMenu.__index = MainMenu

local L = Localization.get

export type Callbacks = {
	onPlay: () -> (),
	onCollection: () -> (),
	onTraining: () -> (),
	onSettings: () -> (),
	onTutorial: () -> (),
	onShop: () -> (),
	onRetryProfile: () -> (),
}

export type MainMenu = typeof(setmetatable(
	{} :: {
		root: Frame,
		callbacks: Callbacks,
		buttons: { [string]: Components.Button },
		compact: boolean,
		artHolder: Frame,
		teamPill: Frame,
		teamPillText: TextLabel,
		balanceChip: Components.Chip,
		statusLabel: TextLabel,
		shopEnabled: boolean,
	},
	MainMenu
))

local function clear(frame: Frame)
	for _, child in ipairs(frame:GetChildren()) do
		child:Destroy()
	end
end

function MainMenu.new(parent: Instance, callbacks: Callbacks): MainMenu
	local root = Components.frame(parent, "MainMenu", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
		Visible = false,
	})
	local self = setmetatable({
		root = root,
		callbacks = callbacks,
		buttons = {},
		compact = Responsive.isCompact(),
		shopEnabled = false,
	}, MainMenu) :: any
	MainMenu.build(self)
	return self
end

function MainMenu.build(self: MainMenu)
	clear(self.root)
	local compact = Responsive.isCompact()
	self.compact = compact
	self.buttons = {}
	local root = self.root

	-- decoração de fundo (não interativa)
	local decor = Components.frame(root, "Decor", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	decor.Active = false
	local blobs: { { position: UDim2, size: number } } = {
		{ position = UDim2.fromScale(0.82, -0.22), size = 460 },
		{ position = UDim2.fromScale(-0.14, 0.66), size = 340 },
	}
	for index, blob in ipairs(blobs) do
		local circle = Components.frame(decor, "Blob" .. index, {
			Position = blob.position,
			Size = UDim2.fromOffset(blob.size, blob.size),
			BackgroundColor3 = Theme.colors.sageDeep,
			BackgroundTransparency = 0.45,
		})
		circle.Active = false
		Components.corner(circle, 999)
	end

	-- selo "Brinquedos em missão" e saldo de botões, fora da faixa de ações
	local badge = Components.panel(root, "Badge", {
		Size = UDim2.fromOffset(10, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(if compact then 20 else 40, if compact then 14 else 34),
		BackgroundColor3 = Theme.colors.surface,
		ZIndex = 2,
	}, { radius = Theme.sizes.pillCorner, shadow = false })
	badge.Active = false
	Components.padding(badge, 14, 4)
	Components.label(badge, "Text", Components.upper(L("app.tagline")), {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.muted,
		TextWrapped = false,
		ZIndex = 3,
	})

	self.balanceChip = Components.statChip(root, "Balance", L("common.buttons"), {
		Size = UDim2.fromOffset(10, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -(if compact then 20 else 40), 0, if compact then 14 else 34),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.colors.gold,
		ZIndex = 2,
	}, "ui_buttons")

	self.statusLabel = Components.caption(root, "Status", "", {
		Size = UDim2.new(0, 360, 0, 18),
		Position = UDim2.new(1, -(if compact then 20 else 40), 0, if compact then 50 else 72),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.colors.danger,
		Visible = false,
		ZIndex = 3,
	})

	local columnWidth = if compact then math.huge else 400
	local column = Components.frame(root, "Column", {
		Size = if compact then UDim2.new(1, -40, 1, -(78 + 20)) else UDim2.new(0, columnWidth, 1, -(120 + 40)),
		Position = if compact then UDim2.fromOffset(20, 78) else UDim2.fromOffset(40, 120),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})

	local heroSize = if compact then 34 else 64
	Components.title(column, "Hero", Components.upper(L("app.title")), {
		Size = UDim2.new(1, 0, 0, if compact then 44 else 150),
		TextSize = Accessibility.scaleText(heroSize),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
	})
	Components.label(column, "Subtitle", L("app.subtitle"), {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, if compact then 46 else 156),
		TextColor3 = Theme.colors.muted,
		ZIndex = 3,
	})

	-- faixa de ações: rolável para caber com texto ampliado sem sair da tela
	local actions = Components.scroller(column, "Actions", {
		Size = UDim2.new(1, 0, 1, -(if compact then 76 else 192)),
		Position = UDim2.fromOffset(0, if compact then 76 else 192),
		ZIndex = 3,
	})
	local grid = Components.list(actions, Enum.FillDirection.Horizontal, 10)
	grid.Wraps = true
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local fullWidth = UDim2.new(1, 0, 0, if compact then 54 else 62)
	local halfWidth = UDim2.new(0.5, -5, 0, Theme.sizes.buttonTarget + 4)

	self.buttons.play = Components.button(actions, {
		name = "Play",
		text = L("menu.play"),
		kind = "primary",
		icon = "ui_play",
		size = fullWidth,
		layoutOrder = 1,
		textSize = if compact then 20 else 24,
		zIndex = 4,
		onActivate = self.callbacks.onPlay,
	})
	self.buttons.collection = Components.button(actions, {
		name = "Collection",
		text = L("menu.collection"),
		kind = "secondary",
		size = halfWidth,
		layoutOrder = 2,
		zIndex = 4,
		onActivate = self.callbacks.onCollection,
	})
	self.buttons.training = Components.button(actions, {
		name = "Training",
		text = L("menu.training"),
		kind = "secondary",
		size = halfWidth,
		layoutOrder = 3,
		zIndex = 4,
		onActivate = self.callbacks.onTraining,
	})
	self.buttons.settings = Components.button(actions, {
		name = "Settings",
		text = L("menu.settings"),
		kind = "secondary",
		icon = "ui_settings",
		size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 4),
		layoutOrder = 4,
		zIndex = 4,
		onActivate = self.callbacks.onSettings,
	})
	self.buttons.tutorial = Components.button(actions, {
		name = "Tutorial",
		text = L("menu.tutorial"),
		kind = "secondary",
		size = halfWidth,
		layoutOrder = 5,
		zIndex = 4,
		onActivate = self.callbacks.onTutorial,
	})
	self.buttons.shop = Components.button(actions, {
		name = "Shop",
		text = L("menu.shop"),
		kind = "ghost",
		size = halfWidth,
		layoutOrder = 6,
		visible = false,
		zIndex = 4,
		onActivate = self.callbacks.onShop,
	})

	-- arte decorativa: some no compacto com texto ampliado, sem levar informação junto
	local showArt = not compact or not Accessibility.get().largeText
	self.artHolder = Components.frame(root, "Art", {
		Size = if compact then UDim2.fromOffset(190, 190) else UDim2.fromOffset(420, 420),
		Position = if compact then UDim2.new(1, -30, 0.55, 0) else UDim2.new(0.72, 0, 0.48, 0),
		AnchorPoint = if compact then Vector2.new(1, 0.5) else Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = showArt,
		ZIndex = 1,
	})
	self.artHolder.Active = false
	local disc = Components.frame(self.artHolder, "Disc", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.surface,
		ZIndex = 1,
	})
	disc.Active = false
	Components.corner(disc, 999)
	Components.stroke(disc, Theme.colors.ink, 2)
	local heroEntry = Assets.get(Assets.towerKey("dardo", "L0"))
	if heroEntry and (heroEntry.portrait or heroEntry.image) then
		local art = Instance.new("ImageLabel")
		art.Name = "Hero"
		art.BackgroundTransparency = 1
		art.Image = (heroEntry.portrait or heroEntry.image) :: string
		art.ScaleType = Enum.ScaleType.Fit
		art.Size = UDim2.fromScale(0.82, 0.82)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Active = false
		art.ZIndex = 2
		art.Parent = self.artHolder
	end
	local baseEntry = Assets.get("base_farol_pilha")
	if baseEntry and baseEntry.image then
		local lighthouse = Instance.new("ImageLabel")
		lighthouse.Name = "Base"
		lighthouse.BackgroundTransparency = 1
		lighthouse.Image = baseEntry.image :: string
		lighthouse.ScaleType = Enum.ScaleType.Fit
		lighthouse.Size = UDim2.fromScale(0.3, 0.3)
		lighthouse.Position = UDim2.fromScale(0.92, 0.88)
		lighthouse.AnchorPoint = Vector2.new(0.5, 0.5)
		lighthouse.Active = false
		lighthouse.ZIndex = 3
		lighthouse.Parent = self.artHolder
	end

	self.teamPill = Components.frame(root, "TeamPill", {
		Size = UDim2.fromOffset(10, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = if compact then UDim2.new(1, -30, 1, -18) else UDim2.new(0.72, 0, 0.92, 0),
		AnchorPoint = if compact then Vector2.new(1, 1) else Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.teal,
		Visible = showArt,
		ZIndex = 3,
	})
	self.teamPill.Active = false
	Components.corner(self.teamPill, 999)
	Components.padding(self.teamPill, 16, 4)
	-- reconstruir a faixa não pode perder o estado da loja (feature flag do servidor)
	MainMenu.setShopEnabled(self, self.shopEnabled)

	self.teamPillText = Components.label(self.teamPill, "Text", "", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.ink,
		TextWrapped = false,
		ZIndex = 4,
	})
end

function MainMenu.setShopEnabled(self: MainMenu, enabled: boolean)
	self.shopEnabled = enabled
	if self.buttons.shop then
		-- desativada, a loja não ocupa espaço nenhum no menu
		self.buttons.shop.instance.Visible = enabled
	end
end

function MainMenu.render(self: MainMenu)
	local profile = Store.profile()
	local status = Store.get().profileStatus

	self.balanceChip:setValue(if profile then tostring(profile.buttons or 0) else "—")
	self.balanceChip.instance.Visible = profile ~= nil

	if profile and not Store.isPersistent() then
		self.statusLabel.Text = L("app.progressNotSaved")
		self.statusLabel.Visible = true
	elseif not profile and status ~= "loading" then
		self.statusLabel.Text = L("app.profileUnavailableShort")
		self.statusLabel.Visible = true
	else
		self.statusLabel.Visible = false
	end

	local play = self.buttons.play
	if not profile then
		play:setText(L("common.retry"), L("app.profileUnavailableShort"))
		play:setAvailable(true)
		play:onActivate(self.callbacks.onRetryProfile)
	elseif not profile.tutorialCompleted then
		-- primeiro acesso: tutorial com opção clara de pular (dentro do próprio tutorial)
		play:setText(L("menu.tutorial"), L("menu.startTutorialHint"))
		play:setAvailable(true)
		play:onActivate(self.callbacks.onTutorial)
	else
		play:setText(L("menu.play"), L("menu.playHint"))
		play:setAvailable(true)
		play:onActivate(self.callbacks.onPlay)
	end

	local tutorial = self.buttons.tutorial
	tutorial:setText(if profile and profile.tutorialCompleted then L("menu.replayTutorial") else L("menu.tutorial"))
	tutorial:setAvailable(profile ~= nil, if profile then nil else L("app.loading"))
	self.buttons.collection:setAvailable(profile ~= nil, if profile then nil else L("app.loading"))

	-- resumo da equipe no selo decorativo: nunca é a única fonte da informação
	local loadout: { string } = if profile then (profile.loadout or {}) else {}
	if #loadout == 0 then
		self.teamPillText.Text = Components.upper(L("menu.teamEmpty"))
	else
		local names = {}
		for _, id in ipairs(loadout) do
			local def = Catalog.getTower(id)
			table.insert(names, if def then def.name else id)
		end
		self.teamPillText.Text = Components.upper(L("menu.teamReady", { team = table.concat(names, " · ") }))
	end
end

function MainMenu.relayout(self: MainMenu)
	if Responsive.isCompact() ~= self.compact then
		MainMenu.build(self)
		if self.root.Visible then
			MainMenu.render(self)
		end
	end
end

function MainMenu.show(self: MainMenu)
	self.root.Visible = true
	MainMenu.render(self)
end

function MainMenu.hide(self: MainMenu)
	self.root.Visible = false
end

return MainMenu
