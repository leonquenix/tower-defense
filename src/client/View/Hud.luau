--!strict
-- HUD de combate: faixa superior, faixa inferior, detalhe de torre/inimigo, prévia de onda, tutorial e treino.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local HudPanels = require(script.Parent.HudPanels)
local Modal = require(script.Parent.Parent.UI.Modal)
local Store = require(script.Parent.Parent.UI.Store)
local MatchController = require(script.Parent.Parent.Controllers.MatchController)
local Motion = require(script.Parent.Motion)
local Responsive = require(script.Parent.Responsive)

local Hud = {}
Hud.__index = Hud

local L = Localization.get

export type Callbacks = {
	onPickTower: (towerId: string) -> (),
	onConfirmBuild: () -> (),
	onCancelBuild: () -> (),
	onPulse: () -> (),
	onSpeedVote: (value: number) -> (),
	onReady: () -> (),
	onLeave: () -> (),
	onZoomReset: () -> (),
	onUpgrade: (entityId: number, nextState: string) -> (),
	onSell: (entityId: number) -> (),
	onTarget: (entityId: number, mode: string) -> (),
	onCloseDetail: () -> (),
	onOpenSettings: () -> (),
	onTrainingSpawn: (enemyId: string, count: number) -> (),
	onTrainingClear: () -> (),
	onToggleRanges: (value: boolean) -> (),
	onToggleCircuits: (value: boolean) -> (),
	onTutorialNext: () -> (),
	onTutorialSkip: () -> (),
}

export type Hud = typeof(setmetatable(
	{} :: {
		root: Frame,
		top: Frame,
		bottom: Frame,
		boardArea: Frame,
		detail: Frame,
		detailBody: ScrollingFrame,
		wavePreview: Frame,
		wavePreviewText: TextLabel,
		tutorialBanner: Frame,
		tutorialText: TextLabel,
		tutorialNext: Ui.Button,
		tutorialSkip: Ui.Button,
		trainingPanel: Frame,
		bossBanner: TextLabel,
		baseText: TextLabel,
		baseBar: Frame,
		waveText: TextLabel,
		phaseText: TextLabel,
		scrapText: TextLabel,
		limitText: TextLabel,
		participants: Frame,
		towerCards: { [string]: Ui.Button },
		cardsRow: Frame,
		pulseButton: Ui.Button,
		speedButton: Ui.Button,
		readyButton: Ui.Button,
		zoomButton: Ui.Button,
		optionsButton: Ui.Button,
		groupButton: Ui.Button,
		bossBar: HudPanels.BossBar,
		targetMenu: HudPanels.TargetMenu,
		speedPopover: HudPanels.SpeedPopover,
		optionsPanel: HudPanels.OptionsPanel,
		connectionBanner: HudPanels.ConnectionBanner,
		buildBar: Frame,
		buildText: TextLabel,
		buildConfirm: Ui.Button,
		buildCancel: Ui.Button,
		callbacks: Callbacks,
		mobile: boolean,
		selectedTowerId: number?,
		selectedEnemyId: number?,
		trainingEnemy: string,
		pulseArmedUntil: number,
		detailDirty: boolean,
		lastRenderedDetailKey: string,
		displayedScrap: number,
		lastBaseHP: number,
		loadoutIds: { string },
	},
	Hud
))

local TOP_HEIGHT = 56
local BOTTOM_HEIGHT = 100
local DETAIL_WIDTH = 280
-- Layout compacto (celular em paisagem): colunas laterais e tabuleiro em altura total
local SIDE_WIDTH = 132
local SIDE_GAP = 6

local function layoutDetail(self: Hud)
	if self.mobile then
		return
	end
	local bottomHeight = BOTTOM_HEIGHT
	local offset = if self.tutorialBanner.Visible then 182 elseif self.trainingPanel.Visible then 226 else 0
	Motion.setBase(self.detail, UDim2.new(1, -(DETAIL_WIDTH + 8), 0, TOP_HEIGHT + 20 + offset))
	self.detail.Size = UDim2.new(0, DETAIL_WIDTH, 1, -(TOP_HEIGHT + 20 + bottomHeight + 20 + offset))
end

local function buildTrainingPanel(self: Hud, root: Frame, callbacks: Callbacks, mobile: boolean): Frame
	local trainingPanel = Ui.panel(root, "Training", {
		Size = if mobile
			then UDim2.new(0, SIDE_WIDTH, 1, -(SIDE_GAP * 2 + 104))
			else UDim2.new(0, DETAIL_WIDTH, 0, 214),
		Position = if mobile
			then UDim2.new(1, -(SIDE_WIDTH + SIDE_GAP), 0, SIDE_GAP + 104)
			else UDim2.new(1, -(DETAIL_WIDTH + 8), 0, TOP_HEIGHT + 20),
		BackgroundColor3 = Theme.colors.cream,
		Visible = false,
		ZIndex = 6,
	})
	Ui.padding(trainingPanel, if mobile then 6 else 10)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ZIndex = 7
	scroll.Parent = trainingPanel
	local list = Ui.list(scroll, Enum.FillDirection.Vertical, 4)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	Ui.label(scroll, "Title", L("hud.training") .. "\n" .. L("hud.trainingNotice"), {
		Size = UDim2.new(1, 0, 0, if mobile then 44 else 48),
		TextSize = if mobile then 11 else 13,
		ZIndex = 7,
		LayoutOrder = 1,
	})
	local picker = Ui.frame(scroll, "Picker", {
		Size = UDim2.new(1, 0, 0, if mobile then 6 * 46 else 62),
		BackgroundTransparency = 1,
		ZIndex = 7,
		LayoutOrder = 2,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = if mobile then UDim2.new(0, 56, 0, 42) else UDim2.new(0, 54, 0, 28)
	grid.CellPadding = UDim2.new(0, 4, 0, 4)
	grid.Parent = picker
	local enemyIds = {}
	for _, e in ipairs(Balance.enemies) do
		table.insert(enemyIds, e.id)
	end
	for _, b in ipairs(Balance.bosses) do
		table.insert(enemyIds, b.id)
	end
	local pickerButtons: { [string]: Ui.Button } = {}
	local function refreshPicker()
		for id, b in pairs(pickerButtons) do
			b:setKind(if id == self.trainingEnemy then "primary" else "secondary")
		end
	end
	for _, id in ipairs(enemyIds) do
		local b = Ui.button(
			picker,
			id,
			L("enemy." .. id):sub(1, 7),
			"secondary",
			{ Size = UDim2.new(0, 54, 0, 28), ZIndex = 8 }
		)
		b.label.TextSize = 11
		local constraint = b.instance:FindFirstChildOfClass("UISizeConstraint")
		if constraint then
			constraint.MinSize = Vector2.new(44, 28)
		end
		b:onClick(function()
			self.trainingEnemy = id
			refreshPicker()
		end)
		pickerButtons[id] = b
	end
	refreshPicker()
	local buttonHeight = if mobile then 44 else 40
	local row1 = Ui.frame(scroll, "Row1", {
		Size = UDim2.new(1, 0, 0, if mobile then buttonHeight * 3 + 8 else buttonHeight),
		BackgroundTransparency = 1,
		ZIndex = 7,
		LayoutOrder = 3,
	})
	Ui.list(
		row1,
		if mobile then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		if mobile then 4 else 6
	)
	local spawn1 = Ui.button(row1, "Spawn1", L("hud.trainingSpawn1"), "primary", {
		Size = if mobile then UDim2.new(1, 0, 0, buttonHeight) else UDim2.new(0, 72, 0, buttonHeight),
		ZIndex = 8,
		LayoutOrder = 1,
	})
	spawn1.label.TextSize = 14
	spawn1:onClick(function()
		callbacks.onTrainingSpawn(self.trainingEnemy, 1)
	end)
	local spawn10 = Ui.button(row1, "Spawn10", L("hud.trainingSpawn10"), "primary", {
		Size = if mobile then UDim2.new(1, 0, 0, buttonHeight) else UDim2.new(0, 72, 0, buttonHeight),
		ZIndex = 8,
		LayoutOrder = 2,
	})
	spawn10.label.TextSize = 14
	spawn10:onClick(function()
		callbacks.onTrainingSpawn(self.trainingEnemy, 10)
	end)
	local clear = Ui.button(row1, "Clear", L("hud.trainingClear"), "danger", {
		Size = if mobile then UDim2.new(1, 0, 0, buttonHeight) else UDim2.new(0, 80, 0, buttonHeight),
		ZIndex = 8,
		LayoutOrder = 3,
	})
	clear.label.TextSize = 12
	clear:onClick(function()
		Modal.open(self.root, {
			title = L("hud.trainingClear"),
			body = L("hud.trainingClearConfirm"),
			confirmText = L("hud.trainingClearAction"),
			danger = true,
			opener = clear.instance,
			onConfirm = function(controls)
				controls:close()
				callbacks.onTrainingClear()
			end,
		})
	end)
	local row2 = Ui.frame(scroll, "Row2", {
		Size = UDim2.new(1, 0, 0, if mobile then buttonHeight * 2 + 4 else buttonHeight),
		BackgroundTransparency = 1,
		ZIndex = 7,
		LayoutOrder = 4,
	})
	Ui.list(
		row2,
		if mobile then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		if mobile then 4 else 6
	)
	local rangesOn, circuitsOn = false, true
	local ranges = Ui.button(row2, "Ranges", L("hud.trainingRanges"), "secondary", {
		Size = if mobile then UDim2.new(1, 0, 0, buttonHeight) else UDim2.new(0, 112, 0, buttonHeight),
		ZIndex = 8,
		LayoutOrder = 1,
	})
	ranges.label.TextSize = 12
	ranges:onClick(function()
		rangesOn = not rangesOn
		ranges:setKind(if rangesOn then "primary" else "secondary")
		callbacks.onToggleRanges(rangesOn)
	end)
	local circuits = Ui.button(row2, "Circuits", L("hud.trainingCircuits"), "primary", {
		Size = if mobile then UDim2.new(1, 0, 0, buttonHeight) else UDim2.new(0, 112, 0, buttonHeight),
		ZIndex = 8,
		LayoutOrder = 2,
	})
	circuits.label.TextSize = 12
	circuits:onClick(function()
		circuitsOn = not circuitsOn
		circuits:setKind(if circuitsOn then "primary" else "secondary")
		callbacks.onToggleCircuits(circuitsOn)
	end)
	return trainingPanel
end

function Hud.new(parent: GuiObject, callbacks: Callbacks, mobile: boolean): Hud
	local root = Ui.frame(parent, "Hud", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local self = setmetatable({
		root = root,
		callbacks = callbacks,
		mobile = mobile,
		towerCards = {},
		selectedTowerId = nil,
		selectedEnemyId = nil,
		trainingEnemy = "fiapo",
		pulseArmedUntil = 0,
		detailDirty = true,
		lastRenderedDetailKey = "",
		displayedScrap = -1,
		lastBaseHP = -1,
		loadoutIds = {},
	}, Hud) :: any

	-- ------------------------------------------------------------------
	-- Faixa superior (computador) ou coluna esquerda de estatísticas (celular)
	-- ------------------------------------------------------------------
	local top = Ui.frame(root, "Top", {
		Size = if mobile then UDim2.new(0, SIDE_WIDTH, 0, 98) else UDim2.new(1, -16, 0, TOP_HEIGHT),
		Position = UDim2.new(0, if mobile then SIDE_GAP else 8, 0, if mobile then SIDE_GAP else 8),
		BackgroundColor3 = Theme.colors.ink,
	})
	Ui.corner(top, if mobile then 10 else Theme.sizes.corner)
	Ui.padding(top, if mobile then 8 else 14, if mobile then 4 else 6)
	self.top = top
	if mobile then
		local list = Ui.list(top, Enum.FillDirection.Vertical, 2)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		local function statRow(name: string, order: number, captionText: string, color: Color3): TextLabel
			local holder =
				Ui.frame(top, name, { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order })
			Ui.label(holder, "Caption", captionText, {
				Size = UDim2.new(0.42, 0, 1, 0),
				TextSize = 10,
				TextColor3 = Theme.colors.cyan,
				Font = Theme.fonts.bodyBold,
			})
			return Ui.label(holder, "Value", "", {
				Size = UDim2.new(0.58, 0, 1, 0),
				Position = UDim2.new(0.42, 0, 0, 0),
				TextSize = 15,
				TextColor3 = color,
				Font = Theme.fonts.numbers,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
		self.baseText = statRow("Base", 1, Ui.upper(L("hud.base")), Theme.colors.cream)
		local baseBarBack = Ui.frame(
			top,
			"BarBack",
			{ Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.colors.muted, LayoutOrder = 2 }
		)
		Ui.corner(baseBarBack, 999)
		self.baseBar =
			Ui.frame(baseBarBack, "Bar", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.gold })
		Ui.corner(self.baseBar, 999)
		self.waveText = statRow("Wave", 3, Ui.upper(L("hud.wave")), Theme.colors.cream)
		self.scrapText = statRow("Scrap", 4, Ui.upper(L("common.scrap")), Theme.colors.gold)
		local phaseHolder =
			Ui.frame(top, "Phase", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 5 })
		self.phaseText = Ui.label(phaseHolder, "Value", "", {
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 11,
			TextColor3 = Theme.colors.cream,
			Font = Theme.fonts.bodyMedium,
		})
		local limitHolder =
			Ui.frame(top, "Limit", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 6 })
		self.limitText = Ui.label(limitHolder, "Value", "", {
			Size = UDim2.new(1, 0, 1, 0),
			TextSize = 10,
			TextColor3 = Theme.colors.muted,
			Font = Theme.fonts.bodyMedium,
		})
		self.participants = Ui.frame(root, "Participants", {
			Size = UDim2.new(0, SIDE_WIDTH, 0, 22),
			Position = UDim2.new(0, SIDE_GAP, 1, -(SIDE_GAP + 22)),
			BackgroundTransparency = 1,
		})
		Ui.list(self.participants, Enum.FillDirection.Horizontal, 4)
	else
		local function stat(name: string, order: number, width: number): (TextLabel, TextLabel)
			local holder = Ui.frame(
				top,
				name,
				{ Size = UDim2.new(0, width, 1, 0), BackgroundTransparency = 1, LayoutOrder = order }
			)
			local caption = Ui.label(holder, "Caption", "", {
				Size = UDim2.new(1, 0, 0, 14),
				TextSize = 11,
				TextColor3 = Theme.colors.cyan,
				Font = Theme.fonts.bodyBold,
			})
			local value = Ui.label(holder, "Value", "", {
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.new(0, 0, 0, 16),
				TextSize = Theme.sizes.numbers,
				TextColor3 = Theme.colors.cream,
				Font = Theme.fonts.numbers,
			})
			return caption, value
		end
		Ui.list(top, Enum.FillDirection.Horizontal, 18)
		local baseCaption, baseValue = stat("Base", 1, 120)
		baseCaption.Text = Ui.upper(L("hud.base"))
		self.baseText = baseValue
		local baseBarBack = Ui.frame(
			baseValue.Parent :: Frame,
			"BarBack",
			{ Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -4), BackgroundColor3 = Theme.colors.muted }
		)
		Ui.corner(baseBarBack, 999)
		self.baseBar =
			Ui.frame(baseBarBack, "Bar", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.gold })
		Ui.corner(self.baseBar, 999)
		local waveCaption, waveValue = stat("Wave", 2, 110)
		waveCaption.Text = Ui.upper(L("hud.wave"))
		self.waveText = waveValue
		local phaseCaption, phaseValue = stat("Phase", 3, 190)
		phaseCaption.Text = ""
		phaseValue.TextSize = 16
		phaseValue.Font = Theme.fonts.bodyMedium
		self.phaseText = phaseValue
		local scrapCaption, scrapValue = stat("Scrap", 4, 130)
		scrapCaption.Text = Ui.upper(L("hud.scrap"))
		scrapValue.TextColor3 = Theme.colors.gold
		self.scrapText = scrapValue
		local limitCaption, limitValue = stat("Limit", 5, 110)
		limitCaption.Text = ""
		limitValue.TextSize = 14
		limitValue.Font = Theme.fonts.bodyMedium
		self.limitText = limitValue
		local participants = Ui.frame(
			top,
			"Participants",
			{ Size = UDim2.new(1, -890, 1, 0), BackgroundTransparency = 1, LayoutOrder = 6 }
		)
		Ui.list(participants, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
		self.participants = participants
	end

	-- ------------------------------------------------------------------
	-- Área do tabuleiro
	-- ------------------------------------------------------------------
	local bottomHeight = BOTTOM_HEIGHT
	local boardArea = Ui.frame(root, "BoardArea", {
		Position = if mobile
			then UDim2.new(0, SIDE_WIDTH + SIDE_GAP * 2, 0, SIDE_GAP)
			else UDim2.new(0, 8, 0, TOP_HEIGHT + 20),
		Size = if mobile
			then UDim2.new(1, -(SIDE_WIDTH * 2 + SIDE_GAP * 4), 1, -(SIDE_GAP * 2))
			else UDim2.new(1, -(DETAIL_WIDTH + 28), 1, -(TOP_HEIGHT + 20 + bottomHeight + 20)),
		BackgroundTransparency = 1,
	})
	self.boardArea = boardArea

	-- ------------------------------------------------------------------
	-- Painel de detalhe (lateral no computador; folha inferior no celular)
	-- ------------------------------------------------------------------
	local detail = Ui.panel(root, "Detail", {
		Size = if mobile
			then UDim2.new(1, -(SIDE_WIDTH * 2 + SIDE_GAP * 4), 0, 150)
			else UDim2.new(0, DETAIL_WIDTH, 1, -(TOP_HEIGHT + 20 + bottomHeight + 20)),
		Position = if mobile
			then UDim2.new(0, SIDE_WIDTH + SIDE_GAP * 2, 1, -(150 + SIDE_GAP))
			else UDim2.new(1, -(DETAIL_WIDTH + 8), 0, TOP_HEIGHT + 20),
		Visible = false,
		ZIndex = 5,
	})
	Ui.padding(detail, if mobile then 8 else 14)
	local closeDetail = Ui.button(
		detail,
		"Close",
		"✕",
		"ghost",
		{ Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(1, -44, 0, 0), ZIndex = 8 }
	)
	closeDetail:onClick(function()
		callbacks.onCloseDetail()
	end)
	local detailBody = Instance.new("ScrollingFrame")
	detailBody.Name = "Body"
	detailBody.BackgroundTransparency = 1
	detailBody.BorderSizePixel = 0
	detailBody.Size = UDim2.new(1, 0, 1, 0)
	detailBody.CanvasSize = UDim2.new()
	detailBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailBody.ScrollBarThickness = 4
	detailBody.ZIndex = 6
	detailBody.Parent = detail
	self.detail = detail
	self.detailBody = detailBody

	-- ------------------------------------------------------------------
	-- Faixa inferior (computador) / cartas na coluna esquerda e ações na coluna direita (celular)
	-- ------------------------------------------------------------------
	local bottom = Ui.frame(root, "Bottom", {
		Size = if mobile
			then UDim2.new(0, SIDE_WIDTH, 1, -(98 + SIDE_GAP * 3 + 24))
			else UDim2.new(1, -16, 0, bottomHeight),
		Position = if mobile
			then UDim2.new(0, SIDE_GAP, 0, 98 + SIDE_GAP * 2)
			else UDim2.new(0, 8, 1, -(bottomHeight + 8)),
		BackgroundTransparency = 1,
	})
	self.bottom = bottom
	local cardsRow: Frame
	local actions: Frame
	if mobile then
		cardsRow = Ui.frame(bottom, "Cards", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 })
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 62, 0, 50)
		grid.CellPadding = UDim2.new(0, 4, 0, 4)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = cardsRow
		actions = Ui.frame(root, "Actions", {
			Size = UDim2.new(0, SIDE_WIDTH, 1, -(SIDE_GAP * 2)),
			Position = UDim2.new(1, -(SIDE_WIDTH + SIDE_GAP), 0, SIDE_GAP),
			BackgroundTransparency = 1,
		})
		local list = Ui.list(actions, Enum.FillDirection.Vertical, 4)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		Ui.list(bottom, Enum.FillDirection.Horizontal, 10)
		cardsRow = Ui.frame(bottom, "Cards", {
			Size = UDim2.new(0, 10, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		})
		Ui.list(cardsRow, Enum.FillDirection.Horizontal, 8)
		actions = bottom
	end
	self.cardsRow = cardsRow
	local actionSize = if mobile then UDim2.new(1, 0, 0, 48) else nil
	self.pulseButton = Ui.button(
		actions,
		"Pulse",
		L("hud.pulse"),
		"cyan",
		{ Size = actionSize or UDim2.new(0, 190, 1, 0), LayoutOrder = 2 }
	)
	self.pulseButton:onClick(function()
		callbacks.onPulse()
	end)
	self.speedButton = Ui.button(
		actions,
		"Speed",
		L("hud.speed", { value = 1 }),
		"dark",
		{ Size = actionSize or UDim2.new(0, 150, 1, 0), LayoutOrder = 3 }
	)
	self.speedButton:setText(L("hud.speed", { value = 1 }), L("hud.speedHint"))
	self.speedButton:onClick(function()
		-- o popover mostra votos, quem falta e o retorno a 1x antes de qualquer voto
		local view = MatchController.current()
		if view then
			self.speedPopover:toggle(self.speedButton.instance, view, function(value: number)
				callbacks.onSpeedVote(value)
			end)
		end
	end)
	self.readyButton = Ui.button(
		actions,
		"Ready",
		L("hud.ready"),
		"primary",
		{ Size = actionSize or UDim2.new(0, 150, 1, 0), LayoutOrder = 4 }
	)
	self.readyButton:onClick(function()
		callbacks.onReady()
	end)
	self.zoomButton = Ui.button(
		actions,
		"Zoom",
		L("hud.zoomReset"),
		"ghost",
		{ Size = if mobile then UDim2.new(1, 0, 0, 40) else UDim2.new(0, 96, 1, 0), LayoutOrder = 5, Visible = false }
	)
	self.zoomButton:onClick(function()
		callbacks.onZoomReset()
	end)
	-- "Grupo" e "Opções" ficam na faixa superior no computador e na coluna de ações no celular.
	-- Opções reúne grupo em leitura, configurações e saída (o combate não pausa em nenhum caso).
	self.groupButton = Ui.button(
		if mobile then actions else top,
		"Group",
		L("hud.group"),
		"secondary",
		{ Size = if mobile then UDim2.new(1, 0, 0, 44) else UDim2.new(0, 145, 0, 44), LayoutOrder = 6 }
	)
	self.groupButton:onClick(function()
		local view = MatchController.current()
		if view then
			self.optionsPanel:toggle(self.groupButton.instance, view)
		end
	end)
	self.optionsButton = Ui.button(
		if mobile then actions else top,
		"Options",
		L("hud.options"),
		"secondary",
		{ Size = if mobile then UDim2.new(1, 0, 0, 44) else UDim2.new(0, 160, 0, 44), LayoutOrder = 7 }
	)
	self.optionsButton:onClick(function()
		local view = MatchController.current()
		if view then
			self.optionsPanel:toggle(self.optionsButton.instance, view)
		end
	end)
	if mobile then
		for _, b in ipairs({
			self.pulseButton,
			self.speedButton,
			self.readyButton,
			self.zoomButton,
			self.groupButton,
			self.optionsButton,
		}) do
			b.label.TextSize = 14
			b.sub.TextSize = 10
		end
	end

	-- ------------------------------------------------------------------
	-- Barra de construção
	-- ------------------------------------------------------------------
	local buildBar = Ui.panel(root, "BuildBar", {
		Size = if mobile then UDim2.new(1, -(SIDE_WIDTH * 2 + SIDE_GAP * 4), 0, 48) else UDim2.new(0, 520, 0, 56),
		Position = if mobile then UDim2.new(0.5, 0, 1, -SIDE_GAP) else UDim2.new(0.5, 0, 1, -(bottomHeight + 20)),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		ZIndex = 7,
	})
	Ui.padding(buildBar, if mobile then 6 else 10, if mobile then 2 else 6)
	Ui.list(buildBar, Enum.FillDirection.Horizontal, 8)
	self.buildText = Ui.label(buildBar, "Text", "", {
		Size = UDim2.new(1, if mobile then -230 else -300, 1, 0),
		LayoutOrder = 1,
		ZIndex = 8,
		Font = Theme.fonts.bodyMedium,
		TextSize = if mobile then 12 else Theme.sizes.body,
	})
	self.buildCancel = Ui.button(
		buildBar,
		"Cancel",
		L("common.cancel"),
		"secondary",
		{ Size = UDim2.new(0, if mobile then 90 else 110, 0, 44), LayoutOrder = 2, ZIndex = 8 }
	)
	self.buildCancel:onClick(function()
		callbacks.onCancelBuild()
	end)
	self.buildConfirm = Ui.button(
		buildBar,
		"Confirm",
		L("common.confirm"),
		"primary",
		{ Size = UDim2.new(0, if mobile then 130 else 170, 0, 44), LayoutOrder = 3, ZIndex = 8 }
	)
	self.buildConfirm:onClick(function()
		callbacks.onConfirmBuild()
	end)
	if mobile then
		self.buildCancel.label.TextSize = 13
		self.buildConfirm.label.TextSize = 13
	end
	self.buildBar = buildBar

	-- ------------------------------------------------------------------
	-- Prévia da próxima onda e aviso de chefe
	-- ------------------------------------------------------------------
	local wavePreview = Ui.panel(root, "WavePreview", {
		Size = if mobile then UDim2.new(1, -(SIDE_WIDTH * 2 + SIDE_GAP * 4), 0, 24) else UDim2.new(0, 10, 0, 34),
		AutomaticSize = if mobile then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Position = if mobile
			then UDim2.new(0, SIDE_WIDTH + SIDE_GAP * 2, 0, SIDE_GAP)
			else UDim2.new(0, 16, 0, TOP_HEIGHT + 26),
		BackgroundColor3 = Theme.colors.cream,
		BackgroundTransparency = if mobile then 0.15 else 0,
		ZIndex = 4,
	})
	Ui.padding(wavePreview, if mobile then 6 else 10, if mobile then 2 else 4)
	self.wavePreviewText = Ui.label(wavePreview, "Text", "", {
		Size = if mobile then UDim2.new(1, 0, 1, 0) else UDim2.new(0, 0, 1, 0),
		AutomaticSize = if mobile then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		TextSize = if mobile then 11 else 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
		Font = Theme.fonts.bodyMedium,
	})
	self.wavePreview = wavePreview

	self.bossBanner = Ui.label(root, "BossBanner", "", {
		Size = UDim2.new(0, 10, 0, if mobile then 26 else 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 0, if mobile then SIDE_GAP + 28 else TOP_HEIGHT + 26),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.dangerSoft,
		TextColor3 = Theme.colors.danger,
		Font = Theme.fonts.bodyBold,
		TextSize = if mobile then 12 else Theme.sizes.body,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 6,
	})
	Ui.corner(self.bossBanner, 10)
	Ui.stroke(self.bossBanner, Theme.colors.danger, 2)
	Ui.padding(self.bossBanner, 12, 4)

	-- ------------------------------------------------------------------
	-- Tutorial
	-- ------------------------------------------------------------------
	local tutorialBanner = Ui.panel(root, "Tutorial", {
		Size = if mobile
			then UDim2.new(1, -(SIDE_WIDTH * 2 + SIDE_GAP * 4), 0, 74)
			else UDim2.new(0, DETAIL_WIDTH, 0, 170),
		Position = if mobile
			then UDim2.new(0.5, 0, 0, SIDE_GAP + 30)
			else UDim2.new(1, -(DETAIL_WIDTH + 8), 0, TOP_HEIGHT + 20),
		AnchorPoint = if mobile then Vector2.new(0.5, 0) else Vector2.new(0, 0),
		BackgroundColor3 = Theme.colors.cream,
		Visible = false,
		ZIndex = 8,
	})
	Ui.padding(tutorialBanner, if mobile then 8 else 12, if mobile then 4 else 8)
	self.tutorialText = Ui.label(tutorialBanner, "Text", "", {
		Size = if mobile then UDim2.new(1, -110, 1, 0) else UDim2.new(1, 0, 1, -48),
		ZIndex = 9,
		Font = Theme.fonts.bodyMedium,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = if mobile then 12 else 15,
	})
	self.tutorialNext = Ui.button(tutorialBanner, "Next", L("tutorial.next"), "primary", {
		Size = UDim2.new(0, if mobile then 100 else 104, 0, if mobile then 32 else 40),
		Position = if mobile then UDim2.new(1, -100, 0, 0) else UDim2.new(0, 0, 1, -40),
		ZIndex = 9,
	})
	self.tutorialNext:onClick(function()
		callbacks.onTutorialNext()
	end)
	self.tutorialSkip = Ui.button(tutorialBanner, "Skip", L("tutorial.skip"), "ghost", {
		Size = UDim2.new(0, if mobile then 100 else 120, 0, if mobile then 28 else 34),
		Position = if mobile then UDim2.new(1, -100, 1, -30) else UDim2.new(1, -120, 1, -37),
		ZIndex = 9,
	})
	self.tutorialSkip.label.TextSize = if mobile then 11 else 13
	self.tutorialNext.label.TextSize = if mobile then 13 else Theme.sizes.bodyLarge
	if mobile then
		local nextConstraint = self.tutorialNext.instance:FindFirstChildOfClass("UISizeConstraint")
		if nextConstraint then
			nextConstraint.MinSize = Vector2.new(44, 32)
		end
		local skipConstraint = self.tutorialSkip.instance:FindFirstChildOfClass("UISizeConstraint")
		if skipConstraint then
			skipConstraint.MinSize = Vector2.new(44, 28)
		end
	end
	self.tutorialSkip:onClick(function()
		callbacks.onTutorialSkip()
	end)
	self.tutorialBanner = tutorialBanner

	-- ------------------------------------------------------------------
	-- Painel de treino
	-- ------------------------------------------------------------------
	self.trainingPanel = buildTrainingPanel(self, root, callbacks, mobile)

	-- ------------------------------------------------------------------
	-- Painéis contextuais (chefe, alvo, velocidade, opções e conexão)
	-- ------------------------------------------------------------------
	self.bossBar = HudPanels.bossBar(root, mobile)
	self.targetMenu = HudPanels.targetMenu(root)
	self.speedPopover = HudPanels.speedPopover(root)
	self.connectionBanner = HudPanels.connectionBanner(root)
	self.optionsPanel = HudPanels.optionsPanel(root, {
		onSettings = callbacks.onOpenSettings,
		onLeave = callbacks.onLeave,
	})

	return self
end

-- ---------------------------------------------------------------------------
-- Cartas de torre
-- ---------------------------------------------------------------------------

function Hud.setLoadout(self: Hud, towerIds: { string })
	self.loadoutIds = table.clone(towerIds)
	for _, b in pairs(self.towerCards) do
		b:destroy()
	end
	self.towerCards = {}
	local cardWidth = 62
	if not self.mobile then
		-- ajusta as cartas à largura disponível (faixa inferior menos as ações e os espaçamentos)
		local logicalWidth = self.bottom.AbsoluteSize.X / math.max(Responsive.get().scale, 1)
		local maxWidth = if #towerIds > 4 then 104 else 128
		if logicalWidth > 0 then
			local available = logicalWidth - 640 - 8 * (#towerIds - 1)
			cardWidth = math.clamp(math.floor(available / math.max(#towerIds, 1)), 84, maxWidth)
		else
			cardWidth = maxWidth
		end
	end
	for i, towerId in ipairs(towerIds) do
		local def = Catalog.getTower(towerId)
		if def then
			local b = Ui.button(
				self.cardsRow,
				"Card_" .. towerId,
				def.name,
				"secondary",
				{ Size = UDim2.new(0, cardWidth, 1, 0), LayoutOrder = i }
			)
			b:setText(def.name, tostring(def.states.L0.cost) .. " " .. L("common.scraps"))
			local portraitKey = Assets.towerKey(towerId, "L0")
			local entry = Assets.get(portraitKey)
			if self.mobile then
				b.label.TextSize = 12
				b.label.TextScaled = false
				b.sub.TextSize = 9
				b.sub.Position = UDim2.new(0, 4, 1, -14)
				b.sub.Size = UDim2.new(1, -8, 0, 12)
				b.label.Position = UDim2.new(0, 4, 0, -5)
				b.label.Size = UDim2.new(1, -8, 1, 0)
			elseif entry and entry.image then
				local icon = Instance.new("ImageLabel")
				icon.BackgroundTransparency = 1
				icon.Image = entry.portrait or entry.image :: string
				icon.ScaleType = Enum.ScaleType.Fit
				icon.Size = UDim2.new(0, 34, 0, 34)
				icon.Position = UDim2.new(0, 4, 0, 4)
				icon.ZIndex = b.instance.ZIndex + 1
				icon.Parent = b.instance
				b.label.Position = UDim2.new(0, 22, 0, -6)
				b.label.Size = UDim2.new(1, -30, 1, 0)
			end
			local hotkey = Ui.label(b.instance, "Hotkey", tostring(i), {
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(1, -18, 0, 2),
				TextSize = 11,
				TextColor3 = Theme.colors.muted,
				Visible = not self.mobile,
			})
			hotkey.TextXAlignment = Enum.TextXAlignment.Right
			b:onClick(function()
				self.callbacks.onPickTower(towerId)
			end)
			self.towerCards[towerId] = b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Atualização por frame
-- ---------------------------------------------------------------------------

local function phaseLabel(snapshot: Types.MatchSnapshot, simTime: number): string
	if snapshot.phaseEndsAt == math.huge then
		return if snapshot.phase == "Preparation" or snapshot.phase == "Intermission"
			then L("hud.ready") .. " →"
			else ""
	end
	if snapshot.phase == "Preparation" then
		return L("hud.preparation", { seconds = math.max(0, math.ceil(snapshot.phaseEndsAt - simTime)) })
	elseif snapshot.phase == "Intermission" then
		return L("hud.intermission", { seconds = math.max(0, math.ceil(snapshot.phaseEndsAt - simTime)) })
	end
	return ""
end

local function wavePreviewText(groups: { Types.WaveGroup }?): string
	if not groups or #groups == 0 then
		return ""
	end
	local parts = {}
	local traits = {}
	for _, g in ipairs(groups) do
		table.insert(parts, tostring(g.count) .. "× " .. L("enemy." .. g.enemy))
		if Localization.has("enemy.trait." .. g.enemy) and (g.enemy ~= "fiapo") then
			table.insert(traits, L("enemy.trait." .. g.enemy))
		end
	end
	local text = L("hud.nextWave") .. ": " .. table.concat(parts, ", ")
	if #traits > 0 then
		text ..= "  ·  " .. table.concat(traits, " · ")
	end
	return text
end

function Hud.update(self: Hud, view: MatchController.MatchView, wallet: number, myTowers: number, isMobile: boolean)
	local snapshot = view.snapshot
	local simTime = MatchController.estimateSimTime()
	self.baseText.Text = tostring(math.max(0, math.floor(snapshot.baseHP))) .. " / " .. tostring(Balance.baseHP)
	if self.lastBaseHP ~= snapshot.baseHP then
		self.lastBaseHP = snapshot.baseHP
		Motion.tween(
			self.baseBar,
			{ Size = UDim2.fromScale(math.clamp(snapshot.baseHP / Balance.baseHP, 0, 1), 1) },
			0.25
		)
	end
	self.baseBar.BackgroundColor3 = if snapshot.baseHP <= 30 then Theme.colors.danger else Theme.colors.gold
	if snapshot.mode == "training" then
		self.waveText.Text = "—"
	else
		self.waveText.Text = string.format("%02d / %02d", math.max(snapshot.waveIndex, 0), snapshot.totalWaves)
	end
	self.phaseText.Text = phaseLabel(snapshot, simTime)
	if self.displayedScrap < 0 then
		self.displayedScrap = wallet
	end
	self.displayedScrap = Motion.lerpNumber(self.displayedScrap, wallet, 0.45)
	self.scrapText.Text = if snapshot.mode == "training" then "∞" else Ui.formatNumber(self.displayedScrap)
	self.limitText.Text = L("hud.towerLimit", { placed = myTowers, limit = snapshot.limits.perPlayer })
	self.bossBar:update(view, simTime)
	self.connectionBanner:setState(Store.get().connection)
	local connected = 0
	for _, participant in ipairs(snapshot.participants) do
		if participant.connected then
			connected += 1
		end
	end
	self.groupButton.instance.Visible = #snapshot.participants > 1
	self.groupButton:setText(L("hud.groupCount", { ready = connected, total = #snapshot.participants }))
	-- participantes
	for _, child in ipairs(self.participants:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #snapshot.participants > 1 then
		for _, p in ipairs(snapshot.participants) do
			local owner = Theme.owners[p.color] or Theme.owners[1]
			local chip = Ui.label(
				self.participants,
				"P" .. p.userId,
				owner.glyph
					.. " "
					.. p.name
					.. (
						if not p.connected
							then " ⌛"
							else (if p.ready
									and (snapshot.phase == "Preparation" or snapshot.phase == "Intermission")
								then " ✓"
								else "")
					),
				{
					Size = UDim2.new(0, 10, 0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					TextColor3 = owner.color,
					TextSize = 13,
					Font = Theme.fonts.bodyBold,
					BackgroundTransparency = 0.85,
					BackgroundColor3 = owner.color,
				}
			)
			Ui.corner(chip, 8)
			Ui.padding(chip, 8, 2)
		end
	end
	-- pulso
	local phase: string = snapshot.phase
	local pulseReady = simTime >= snapshot.pulseReadyAt and phase == "Wave"
	self.pulseButton.instance.Visible = snapshot.mode ~= "training"
	if snapshot.mode == "training" or phase ~= "Wave" then
		self.pulseButton:setEnabled(false, if phase == "Wave" then "" else L("hud.pulseReady"))
		self.pulseButton:setText(L("hud.pulse"), "")
	elseif pulseReady then
		if os.clock() < self.pulseArmedUntil then
			self.pulseButton:setEnabled(true, "")
			self.pulseButton:setText(L("common.confirm") .. "?", "")
			self.pulseButton:setKind("primary")
		else
			self.pulseButton:setEnabled(true, "")
			self.pulseButton:setText(L("hud.pulse"), L("hud.pulseReady"))
			self.pulseButton:setKind("cyan")
		end
	else
		self.pulseButton:setEnabled(
			false,
			L("hud.pulseCooldown", { seconds = math.max(0, math.ceil(snapshot.pulseReadyAt - simTime)) })
		)
		self.pulseButton:setText(L("hud.pulse"))
	end
	-- velocidade
	local mySpeedVote = 1
	local activeReady, activeTotal = 0, 0
	for _, p in ipairs(snapshot.participants) do
		if p.userId == MatchController.localUserId then
			mySpeedVote = p.speedVote
		end
		if p.connected then
			activeTotal += 1
			if p.ready then
				activeReady += 1
			end
		end
	end
	self.speedButton:setText(
		L("hud.speed", { value = snapshot.speedMultiplier }),
		if #snapshot.participants > 1 then L("hud.speedHint") .. (if mySpeedVote == 2 then " ✓" else "") else ""
	)
	self.speedButton:setEnabled(snapshot.mode ~= "tutorial", if snapshot.mode == "tutorial" then "1x" else nil)
	self.speedButton:setKind(if snapshot.speedMultiplier == 2 then "primary" else "dark")
	-- pronto
	local canReady = (snapshot.phase == "Preparation" or snapshot.phase == "Intermission")
		and snapshot.mode ~= "training"
	self.readyButton.instance.Visible = canReady
	if canReady then
		local me: Types.ParticipantSnapshot? = nil
		for _, p in ipairs(snapshot.participants) do
			if p.userId == MatchController.localUserId then
				me = p
			end
		end
		local ready = me ~= nil and (me :: Types.ParticipantSnapshot).ready
		self.readyButton:setText(
			if ready then "✓ " .. L("hud.ready") else L("hud.ready"),
			if #snapshot.participants > 1 then L("hud.readyCount", { ready = activeReady, total = activeTotal }) else ""
		)
		self.readyButton:setKind(if ready then "secondary" else "primary")
	end
	-- cartas
	for towerId, card in pairs(self.towerCards) do
		local def = Catalog.getTower(towerId)
		if def then
			local cost = def.states.L0.cost
			local count = MatchController.myTowerCountOf(towerId)
			local reason: string? = nil
			if snapshot.mode ~= "training" and wallet < cost then
				reason = L("build.noFunds", { missing = cost - wallet })
			elseif count >= def.perPlayerLimit or myTowers >= snapshot.limits.perPlayer then
				reason = L("build.limit")
			end
			card:setEnabled(reason == nil, reason or (tostring(cost) .. " " .. L("common.scraps")))
		end
	end
	-- prévia de onda
	local previewText = if snapshot.mode ~= "training"
			and snapshot.phase ~= "Won"
			and snapshot.phase ~= "Lost"
		then wavePreviewText(snapshot.nextWavePreview)
		else ""
	if snapshot.mode ~= "training" and snapshot.waveIndex >= snapshot.totalWaves and snapshot.phase == "Wave" then
		local map = Catalog.getMap(snapshot.mapId)
		if map then
			previewText = L("hud.bossIncoming", { name = L("enemy." .. map.boss) })
		end
	end
	self.wavePreview.Visible = previewText ~= "" and not self.tutorialBanner.Visible
	self.wavePreviewText.Text = previewText
	local trainingVisible = snapshot.mode == "training" and (not self.mobile or not self.detail.Visible)
	if self.trainingPanel.Visible ~= trainingVisible then
		if trainingVisible then
			Motion.slideIn(self.trainingPanel, if self.mobile then 40 else 40, 0)
		else
			Motion.slideOut(self.trainingPanel, 40, 0)
		end
		layoutDetail(self)
	end
	if isMobile then
		self.wavePreview.Position = UDim2.new(0, 16, 0, TOP_HEIGHT + 26)
	end
	Hud.refreshDetail(self, view, wallet)
end

-- ---------------------------------------------------------------------------
-- Modo de construção
-- ---------------------------------------------------------------------------

function Hud.setBuildMode(
	self: Hud,
	towerId: string?,
	cell: Types.Cell?,
	valid: boolean,
	reason: string?,
	cost: number?,
	circuitText: string?
)
	if not towerId then
		if self.buildBar.Visible then
			Motion.slideOut(self.buildBar, 0, 30)
		end
		for _, card in pairs(self.towerCards) do
			card:setKind("secondary")
		end
		return
	end
	if not self.buildBar.Visible then
		Motion.slideIn(self.buildBar, 0, 30)
	end
	for id, card in pairs(self.towerCards) do
		card:setKind(if id == towerId then "primary" else "secondary")
	end
	local def = Catalog.getTower(towerId)
	local name = if def then def.name else towerId
	if not cell then
		self.buildText.Text = L("build.pickCell", { tower = name })
		self.buildConfirm:setEnabled(false, "")
		self.buildConfirm:setText(L("build.confirm", { cost = cost or 0 }))
	else
		local text = if valid then (circuitText or L("build.noCircuit")) else L(reason or "build.invalidCell")
		self.buildText.Text = text
		self.buildConfirm:setEnabled(valid, "")
		self.buildConfirm:setText(L("build.confirm", { cost = cost or 0 }))
	end
end

function Hud.armPulse(self: Hud, seconds: number)
	self.pulseArmedUntil = os.clock() + seconds
end

function Hud.isPulseArmed(self: Hud): boolean
	return os.clock() < self.pulseArmedUntil
end

function Hud.disarmPulse(self: Hud)
	self.pulseArmedUntil = 0
end

-- ---------------------------------------------------------------------------
-- Detalhe
-- ---------------------------------------------------------------------------

local function setDetailVisible(self: Hud, visible: boolean)
	local dx = if self.mobile then 0 else 40
	local dy = if self.mobile then 40 else 0
	if visible then
		if not self.detail.Visible then
			Motion.slideIn(self.detail, dx, dy)
		end
	elseif self.detail.Visible then
		Motion.slideOut(self.detail, dx, dy)
	end
end

function Hud.showTowerDetail(self: Hud, towerId: number?)
	self.selectedTowerId = towerId
	self.selectedEnemyId = nil
	self.detailDirty = true
	layoutDetail(self)
	setDetailVisible(self, towerId ~= nil)
end

function Hud.showEnemyDetail(self: Hud, enemyId: number?)
	self.selectedEnemyId = enemyId
	self.selectedTowerId = nil
	self.detailDirty = true
	setDetailVisible(self, enemyId ~= nil)
end

local function statLines(def: Types.TowerDef, stats: Types.TowerStateStats): { string }
	local lines = {}
	if def.damageType ~= "none" then
		table.insert(lines, L("detail.damage", { value = Ui.formatDecimal(stats.damage, 1) }))
		table.insert(lines, L("detail.interval", { value = Ui.formatDecimal(stats.interval, 2) }))
	end
	table.insert(lines, L("detail.range", { value = Ui.formatDecimal(stats.range, 1) }))
	if stats.haste then
		table.insert(lines, L("detail.haste", { value = math.floor(stats.haste * 100 + 0.5) }))
	end
	if stats.slow and stats.slowDuration then
		table.insert(
			lines,
			L(
				"detail.slow",
				{ value = math.floor(stats.slow * 100 + 0.5), duration = Ui.formatDecimal(stats.slowDuration, 1) }
			)
		)
	end
	if stats.splash then
		table.insert(lines, L("detail.splash", { value = Ui.formatDecimal(stats.splash, 1) }))
	end
	if stats.chains then
		table.insert(lines, L("detail.chains", { value = stats.chains }))
	end
	if stats.armorIgnore then
		table.insert(lines, "armorIgnore " .. Ui.formatDecimal(stats.armorIgnore, 1))
	end
	if stats.bossBonus then
		table.insert(lines, "+" .. math.floor(stats.bossBonus * 100 + 0.5) .. "% vs chefe")
	end
	if stats.mark then
		table.insert(
			lines,
			"marca "
				.. math.floor(stats.mark * 100 + 0.5)
				.. "% / "
				.. Ui.formatDecimal(stats.markDuration or 0, 1)
				.. " s"
		)
	end
	return lines
end

function Hud.refreshDetail(self: Hud, view: MatchController.MatchView, wallet: number)
	if not self.detail.Visible then
		return
	end
	local snapshot = view.snapshot
	local key = ""
	local towerId = self.selectedTowerId
	local tower = if towerId then view.towers[towerId] else nil
	if towerId and not tower then
		Hud.showTowerDetail(self, nil)
		self.callbacks.onCloseDetail()
		return
	end
	if tower then
		key = "t"
			.. tower.id
			.. tower.st
			.. tostring(tower.cp)
			.. tower.tm
			.. tostring(wallet >= 0)
			.. tostring(tower.du > snapshot.simTime)
			.. tostring(wallet)
	elseif self.selectedEnemyId then
		local ev = view.enemies[self.selectedEnemyId :: number]
		if not ev then
			Hud.showEnemyDetail(self, nil)
			return
		end
		key = "e" .. ev.id .. math.floor(ev.hp) .. ":" .. string.format("%.2f", ev.armor)
	end
	if key == self.lastRenderedDetailKey and not self.detailDirty then
		return
	end
	self.lastRenderedDetailKey = key
	self.detailDirty = false
	for _, c in ipairs(self.detailBody:GetChildren()) do
		c:Destroy()
	end
	local body = self.detailBody
	local list = Ui.list(body, Enum.FillDirection.Vertical, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	local order = 0
	local function add(inst: GuiObject)
		order += 1
		inst.LayoutOrder = order
	end
	if tower then
		local t = tower :: Types.TowerSnapshot
		local def = Catalog.getTower(t.d) :: Types.TowerDef
		local stats = Catalog.getStateStats(t.d, t.st) :: Types.TowerStateStats
		local isMine = t.o == MatchController.localUserId
		local branch = Catalog.getBranchName(t.d, t.st)
		add(Ui.title(body, "Name", Ui.upper(def.name), { Size = UDim2.new(1, -44, 0, 30), TextSize = 24, ZIndex = 7 }))
		add(
			Ui.label(
				body,
				"Role",
				def.role .. "  /  " .. t.st .. (if branch then " · " .. branch else ""),
				{ Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = Theme.colors.muted, ZIndex = 7 }
			)
		)
		if not isMine then
			local ownerName = MatchController.participantName(t.o)
			add(
				Ui.label(
					body,
					"Owner",
					L("detail.owner", { owner = ownerName }) .. " · " .. L("detail.notYours"),
					{ Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextColor3 = Theme.colors.muted, ZIndex = 7 }
				)
			)
		end
		for i, line in ipairs(statLines(def, stats)) do
			add(
				Ui.label(
					body,
					"Stat" .. i,
					line,
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = Theme.fonts.bodyMedium, ZIndex = 7 }
				)
			)
		end
		if t.du > snapshot.simTime then
			add(
				Ui.label(
					body,
					"Dust",
					"≋ " .. L("detail.dusted"),
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 13, TextColor3 = Theme.colors.danger, ZIndex = 7 }
				)
			)
		end
		-- circuito
		if t.ci and t.cp then
			local partner = view.towers[t.cp :: number]
			local partnerText = if partner
				then (Catalog.getTower(partner.d) :: Types.TowerDef).name .. " " .. (if partner.o
						~= MatchController.localUserId
					then "(" .. MatchController.participantName(partner.o) .. ")"
					else "")
				else "?"
			add(Ui.label(body, "CircuitTitle", Ui.upper(L("detail.circuit")), {
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 11,
				TextColor3 = Theme.colors.tealDark,
				Font = Theme.fonts.bodyBold,
				ZIndex = 7,
			}))
			add(
				Ui.label(
					body,
					"CircuitName",
					L("circuit." .. (t.ci :: string)),
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 16, Font = Theme.fonts.bodyBold, ZIndex = 7 }
				)
			)
			add(
				Ui.label(
					body,
					"CircuitDesc",
					L("circuit." .. (t.ci :: string) .. ".desc")
						.. "\n"
						.. L("detail.circuitPartner", { partner = partnerText }),
					{ Size = UDim2.new(1, 0, 0, 40), TextSize = 13, ZIndex = 7 }
				)
			)
		else
			local partnerTower = "?"
			for _, c in ipairs(Balance.circuits) do
				if c.pair[1] == t.d then
					partnerTower = (Catalog.getTower(c.pair[2]) :: Types.TowerDef).name
				elseif c.pair[2] == t.d then
					partnerTower = (Catalog.getTower(c.pair[1]) :: Types.TowerDef).name
				end
			end
			add(
				Ui.label(
					body,
					"NoCircuit",
					L("detail.noCircuit", { partnerTower = partnerTower }),
					{ Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextColor3 = Theme.colors.muted, ZIndex = 7 }
				)
			)
		end
		if isMine then
			local nexts = Catalog.TRANSITIONS[t.st] or {}
			local training = snapshot.mode == "training"
			if #nexts == 1 then
				local nextState = nexts[1]
				local nextStats = Catalog.getStateStats(t.d, nextState) :: Types.TowerStateStats
				-- upgrade linear: comparação inline e um clique (sem modal)
				for line, text in ipairs(HudPanels.compareStates(def, stats, nextStats)) do
					add(Ui.label(body, "Cmp" .. line, text, {
						Size = UDim2.new(1, 0, 0, 18),
						TextSize = 13,
						TextColor3 = Theme.colors.tealDark,
						ZIndex = 7,
					}))
				end
				local b = Ui.button(
					body,
					"Upgrade",
					L("detail.upgrade", { cost = nextStats.cost }),
					"primary",
					{ Size = UDim2.new(1, 0, 0, 46), ZIndex = 7 }
				)
				add(b.instance)
				if not training and wallet < nextStats.cost then
					b:setEnabled(false, L("build.noFunds", { missing = nextStats.cost - wallet }))
				end
				b:onClick(function()
					self.callbacks.onUpgrade(t.id, nextState)
				end)
			elseif #nexts == 2 then
				add(Ui.label(body, "ChooseTitle", Ui.upper(L("detail.choose")), {
					Size = UDim2.new(1, 0, 0, 16),
					TextSize = 11,
					TextColor3 = Theme.colors.tealDark,
					Font = Theme.fonts.bodyBold,
					ZIndex = 7,
				}))
				for _, nextState in ipairs(nexts) do
					local nextStats = Catalog.getStateStats(t.d, nextState) :: Types.TowerStateStats
					local name = Catalog.getBranchName(t.d, nextState) or nextState
					local b = Ui.button(
						body,
						"Spec_" .. nextState,
						name .. " / " .. nextStats.cost,
						"primary",
						{ Size = UDim2.new(1, 0, 0, 46), ZIndex = 7 }
					)
					add(b.instance)
					if not training and wallet < nextStats.cost then
						b:setEnabled(false, L("build.noFunds", { missing = nextStats.cost - wallet }))
					end
					b:onClick(function()
						-- confirmação específica: torre, opção e preço; escolha exclusiva até vender
						Modal.open(self.root, {
							title = L("detail.specTitle", { tower = def.name, name = name }),
							body = L("detail.specConfirm", { name = name }),
							confirmText = L("detail.specChoose", { name = name, cost = nextStats.cost }),
							opener = b.instance,
							width = 520,
							build = function(content)
								for line, text in ipairs(HudPanels.compareStates(def, stats, nextStats)) do
									Ui.label(content, "Cmp" .. line, text, {
										Size = UDim2.new(1, 0, 0, 20),
										LayoutOrder = line,
										TextSize = 14,
										ZIndex = 5,
									})
								end
							end,
							onConfirm = function(controls)
								-- uma escolha pendente impede a alternativa simultânea
								controls:setPending(true)
								self.callbacks.onUpgrade(t.id, nextState)
								controls:close()
							end,
						})
					end)
				end
			end
			if def.damageType ~= "none" then
				local modeBtn = Ui.button(
					body,
					"Target",
					L("detail.target", { mode = L("target." .. t.tm) }),
					"secondary",
					{ Size = UDim2.new(1, 0, 0, 44), ZIndex = 7 }
				)
				add(modeBtn.instance)
				modeBtn:onClick(function()
					self.targetMenu:open(modeBtn.instance, t.tm, function(mode: string)
						self.callbacks.onTarget(t.id, mode)
					end)
				end)
			end
			local refund = math.floor(t.inv * Balance.sellRefund)
			local sell = Ui.button(
				body,
				"Sell",
				L("detail.sell", { refund = refund }),
				"danger",
				{ Size = UDim2.new(1, 0, 0, 44), ZIndex = 7 }
			)
			add(sell.instance)
			sell:onClick(function()
				local circuitImpact = if t.ci
					then L("detail.sellCircuit", { name = L("circuit." .. (t.ci :: string)) })
					else L("detail.sellNoCircuit")
				Modal.open(self.root, {
					title = L("detail.sellTitle", { tower = def.name }),
					body = L("detail.sellConfirm", { tower = def.name, refund = refund }) .. "\n" .. circuitImpact,
					-- Cancelar é o foco inicial (Modal já faz isso) e nunca manda comando
					confirmText = L("detail.sellAction", { refund = refund }),
					danger = true,
					opener = sell.instance,
					onConfirm = function(controls)
						controls:setPending(true)
						self.callbacks.onSell(t.id)
						controls:close()
					end,
				})
			end)
		end
	elseif self.selectedEnemyId then
		local ev = view.enemies[self.selectedEnemyId :: number] :: MatchController.EnemyView
		add(
			Ui.title(
				body,
				"Name",
				Ui.upper(L("enemy." .. ev.defId)),
				{ Size = UDim2.new(1, -44, 0, 30), TextSize = 22, ZIndex = 7 }
			)
		)
		add(
			Ui.label(
				body,
				"Hp",
				math.floor(ev.hp + 0.5) .. " / " .. ev.maxHp,
				{ Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Font = Theme.fonts.numbers, ZIndex = 7 }
			)
		)
		if Localization.has("enemy.trait." .. ev.defId) then
			add(
				Ui.label(
					body,
					"Trait",
					L("enemy.trait." .. ev.defId),
					{ Size = UDim2.new(1, 0, 0, 36), TextSize = 14, ZIndex = 7 }
				)
			)
		end
		if ev.armor > 0 then
			local text = "⛨ " .. L("hud.armorPhysical", { value = math.floor(ev.armor * 100 + 0.5) })
			if ev.armorBonus > 0 then
				text ..= " ↑"
			end
			add(Ui.label(body, "Armor", text, {
				Size = UDim2.new(1, 0, 0, 20),
				TextSize = 14,
				TextColor3 = if ev.armorBonus > 0 then Theme.colors.gold else Theme.colors.sand,
				ZIndex = 7,
			}))
		end
		if ev.energyResistance > 0 then
			add(
				Ui.label(
					body,
					"Energy",
					"◈ " .. L("hud.armorEnergy", { value = math.floor(ev.energyResistance * 100 + 0.5) }),
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = Theme.colors.cyan, ZIndex = 7 }
				)
			)
		end
		if ev.isBoss and Localization.has("boss." .. ev.defId .. ".ability") then
			add(
				Ui.label(
					body,
					"Ability",
					L("boss." .. ev.defId .. ".ability"),
					{ Size = UDim2.new(1, 0, 0, 40), TextSize = 14, TextColor3 = Theme.colors.danger, ZIndex = 7 }
				)
			)
		end
		if ev.slow > 0 then
			add(
				Ui.label(
					body,
					"Slow",
					"▼ " .. math.floor(ev.slow * 100 + 0.5) .. "%",
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = Theme.colors.cyan, ZIndex = 7 }
				)
			)
		end
		if ev.mark > 0 then
			add(
				Ui.label(
					body,
					"Mark",
					"◎ +" .. math.floor(ev.mark * 100 + 0.5) .. "%",
					{ Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = Theme.colors.gold, ZIndex = 7 }
				)
			)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Tutorial, chefe, zoom
-- ---------------------------------------------------------------------------

function Hud.setTutorialStep(self: Hud, step: number?, retry: boolean?)
	if not step or step <= 0 then
		Motion.slideOut(self.tutorialBanner, if self.mobile then 0 else 40, if self.mobile then -30 else 0)
		return
	end
	if not self.tutorialBanner.Visible then
		Motion.slideIn(self.tutorialBanner, if self.mobile then 0 else 40, if self.mobile then -30 else 0)
	else
		Motion.pulse(self.tutorialBanner)
	end
	local key = if step >= 6 then "tutorial.done" else "tutorial.step" .. step
	local text = L(key)
	if retry then
		text = L("tutorial.retry") .. "\n" .. text
	end
	self.tutorialText.Text = text
	self.tutorialSkip.instance.Visible = step < 6
	self.tutorialNext.instance.Visible = true
	layoutDetail(self)
end

function Hud.hideTutorial(self: Hud)
	Motion.slideOut(self.tutorialBanner, if self.mobile then 0 else 40, if self.mobile then -30 else 0)
	self.tutorialBanner.Visible = false
	layoutDetail(self)
end

function Hud.setBossBanner(self: Hud, text: string?)
	local show = text ~= nil and text ~= ""
	if show and (not self.bossBanner.Visible or self.bossBanner.Text ~= text) then
		self.bossBanner.Visible = true
		Motion.popIn(self.bossBanner)
	elseif not show then
		self.bossBanner.Visible = false
	end
	self.bossBanner.Text = text or ""
end

-- Reajusta larguras após redimensionar a janela
function Hud.refit(self: Hud)
	if #self.loadoutIds > 0 then
		Hud.setLoadout(self, self.loadoutIds)
	end
end

-- Verdadeiro quando o ponto de tela está sobre painéis do HUD (faixas, barra de construção, detalhe, tutorial, treino)
function Hud.isPointOverChrome(self: Hud, point: Vector2): boolean
	local candidates: { GuiObject } = {
		self.top,
		self.bottom,
		self.buildBar,
		self.detail,
		self.tutorialBanner,
		self.trainingPanel,
		self.wavePreview,
		self.bossBar.frame,
	}
	for _, frame in ipairs(candidates) do
		if frame.Visible then
			local pos = frame.AbsolutePosition
			local size = frame.AbsoluteSize
			if point.X >= pos.X and point.Y >= pos.Y and point.X <= pos.X + size.X and point.Y <= pos.Y + size.Y then
				return true
			end
		end
	end
	return false
end

function Hud.setZoomVisible(self: Hud, visible: boolean)
	self.zoomButton.instance.Visible = visible
end

function Hud.setVisible(self: Hud, visible: boolean)
	self.root.Visible = visible
end

function Hud.closeContextPanels(self: Hud)
	self.targetMenu:close()
	self.speedPopover:close()
	self.optionsPanel:close()
end

function Hud.destroy(self: Hud)
	Hud.closeContextPanels(self)
	self.root:Destroy()
end

return Hud
