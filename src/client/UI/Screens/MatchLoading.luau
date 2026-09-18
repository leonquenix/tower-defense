--!strict
-- 11_carregamento (e a coluna de recuperação da prancha 42): progresso real e recuperação de falhas.
--
-- Contrato:
--  * o progresso é a quantidade de assets essenciais realmente resolvidos — nada de porcentagem inventada;
--  * imagem rejeitada não impede ver rota e botões: entra o retrato neutro e a opção de recarregar;
--  * aos 10 s informa a demora; aos 20 s permite Voltar, respeitando o estado real da partida no servidor;
--  * o cliente não decide quando o combate começa; se a preparação já começou, o relógio converge
--    ao snapshot em vez de recomeçar a contagem para cada cliente.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)

local MatchLoading = {}
MatchLoading.__index = MatchLoading

local L = Localization.get

local SLOW_AFTER = 10
local ALLOW_BACK_AFTER = 20

export type Callbacks = { onBack: () -> () }

export type MatchLoading = typeof(setmetatable(
	{} :: {
		root: Frame,
		callbacks: Callbacks,
		titleLabel: TextLabel,
		stepLabel: TextLabel,
		detailLabel: TextLabel,
		teamLabel: TextLabel,
		bar: Components.ProgressBar,
		progressLabel: TextLabel,
		backButton: Components.Button,
		retryButton: Components.Button,
		startedAt: number,
		resolved: number,
		total: number,
		failed: { string },
		token: number,
	},
	MatchLoading
))

function MatchLoading.new(parent: Instance, callbacks: Callbacks): MatchLoading
	local root = Components.frame(parent, "MatchLoading", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
		Visible = false,
		ZIndex = 5,
	})
	local panel = Components.panel(root, "Panel", {
		Size = UDim2.new(0, 560, 0, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 6,
	}, { tape = true, shadow = false })
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(560, 320)
	constraint.MinSize = Vector2.new(290, 0)
	constraint.Parent = panel
	Components.padding(panel, 22, 20)

	local self = setmetatable({
		root = root,
		callbacks = callbacks,
		startedAt = os.clock(),
		resolved = 0,
		total = 0,
		failed = {},
		token = 0,
	}, MatchLoading) :: any

	self.titleLabel = Components.title(panel, "Title", L("loading.title"), {
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 28,
		ZIndex = 7,
	})
	self.teamLabel = Components.label(panel, "Team", "", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 40),
		TextSize = Theme.sizes.body,
		ZIndex = 7,
	})
	self.stepLabel = Components.label(panel, "Step", L("loading.step.map"), {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 92),
		Font = Theme.fonts.bodyMedium,
		ZIndex = 7,
	})
	self.bar = Components.progressBar(panel, "Bar", {
		Size = UDim2.new(1, -90, 0, 14),
		Position = UDim2.fromOffset(0, 124),
		ZIndex = 7,
	}, Theme.colors.gold)
	Components.stroke(self.bar.instance, Theme.colors.ink, 2)
	self.progressLabel = Components.label(panel, "Count", "", {
		Size = UDim2.fromOffset(84, 20),
		Position = UDim2.new(1, -84, 0, 121),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.numbers,
		ZIndex = 7,
	})
	self.detailLabel = Components.caption(panel, "Detail", "", {
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 148),
		ZIndex = 7,
	})

	local row = Components.frame(panel, "Row", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
		Position = UDim2.new(0, 0, 1, -Theme.sizes.buttonTarget),
		BackgroundTransparency = 1,
		ZIndex = 7,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	self.retryButton = Components.button(row, {
		name = "Retry",
		text = L("loading.reloadImages"),
		kind = "secondary",
		size = UDim2.fromOffset(230, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 8,
		visible = false,
		onActivate = function()
			MatchLoading.preload(self)
		end,
	})
	self.backButton = Components.button(row, {
		name = "Back",
		text = L("loading.back"),
		kind = "ghost",
		size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 8,
		visible = false,
		onActivate = callbacks.onBack,
	})
	return self
end

-- Lista de assets essenciais desta partida: terreno do mapa, base, elenco usado e chefe do mapa.
local function essentialAssets(mapId: string, loadout: { string }): { string }
	local list: { string } = {}
	local function push(key: string)
		local entry = Assets.get(key)
		if entry and entry.image then
			table.insert(list, entry.image :: string)
		end
	end
	push(Assets.groundKey(mapId))
	push("base_farol_pilha")
	for _, towerId in ipairs(loadout) do
		push(Assets.towerKey(towerId, "L0"))
	end
	local map = Catalog.getMap(mapId)
	if map then
		push(Assets.enemyKey(map.boss, true))
	end
	return list
end

function MatchLoading.preload(self: MatchLoading)
	self.token += 1
	local token = self.token
	self.resolved = 0
	table.clear(self.failed)
	self.retryButton.instance.Visible = false
	local assets = self.root:GetAttribute("assets")
	local list: { string } = if typeof(assets) == "string" then string.split(assets, "|") else {}
	self.total = #list
	MatchLoading.refresh(self)
	if #list == 0 then
		return
	end
	task.spawn(function()
		for _, contentId in ipairs(list) do
			if token ~= self.token then
				return
			end
			local holder = Instance.new("ImageLabel")
			holder.Image = contentId
			local ok = pcall(function()
				ContentProvider:PreloadAsync({ holder })
			end)
			-- falha de uma imagem não bloqueia: ela vira retrato neutro e a partida segue
			if not ok or holder.Image == "" then
				table.insert(self.failed, contentId)
			end
			holder:Destroy()
			self.resolved += 1
			MatchLoading.refresh(self)
		end
	end)
end

function MatchLoading.refresh(self: MatchLoading)
	local total = math.max(self.total, 1)
	self.bar:setProgress(self.resolved / total, false)
	self.progressLabel.Text = string.format("%d/%d", self.resolved, self.total)
	if self.resolved < self.total then
		self.stepLabel.Text = L("loading.step.assets")
	else
		self.stepLabel.Text = L("loading.step.waitingServer")
	end
	if #self.failed > 0 then
		self.detailLabel.Text = L("loading.imagesFailed", { count = #self.failed })
		self.retryButton.instance.Visible = true
	end
end

function MatchLoading.update(self: MatchLoading)
	if not self.root.Visible then
		return
	end
	local elapsed = os.clock() - self.startedAt
	if elapsed >= ALLOW_BACK_AFTER then
		self.backButton.instance.Visible = true
		if #self.failed == 0 then
			self.detailLabel.Text = L("loading.tooLong")
		end
	elseif elapsed >= SLOW_AFTER then
		if #self.failed == 0 then
			self.detailLabel.Text = L("loading.slow")
		end
	end
end

-- Mostra mapa, dificuldade e a equipe congelada da largada.
function MatchLoading.show(self: MatchLoading, mapId: string, difficulty: string, loadout: { string })
	self.root.Visible = true
	self.startedAt = os.clock()
	self.backButton.instance.Visible = false
	self.retryButton.instance.Visible = false
	self.detailLabel.Text = ""
	local map = Catalog.getMap(mapId)
	self.titleLabel.Text = if map then map.name else mapId
	local names = {}
	for _, towerId in ipairs(loadout) do
		local def = Catalog.getTower(towerId)
		table.insert(names, if def then def.name else towerId)
	end
	self.teamLabel.Text = L("loading.setup", {
		difficulty = L("menu.difficulty." .. difficulty),
		team = if #names > 0 then table.concat(names, " · ") else L("menu.teamEmpty"),
	})
	self.root:SetAttribute("assets", table.concat(essentialAssets(mapId, loadout), "|"))
	MatchLoading.preload(self)
end

function MatchLoading.hide(self: MatchLoading)
	self.token += 1
	self.root.Visible = false
end

return MatchLoading
