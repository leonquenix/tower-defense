--!strict
-- HUD de combate. Faixa superior com fichas, área do tabuleiro, doca de torres e os painéis
-- contextuais (construção, objetivos, guia da primeira fase, chefe, conexão).
--
-- Tudo é leitura dos átomos: o HUD não guarda estado de partida nem decide preço, dano ou
-- resultado. Quando um botão é apertado, quem fala com o servidor é Controllers/GameFlow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Stars = require(ReplicatedStorage.Shared.Rules.Stars)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local BoardPresenter = require(script.Parent.Parent.Parent.Controllers.BoardPresenter)
local InputController = require(script.Parent.Parent.Parent.Controllers.InputController)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Responsive = require(script.Parent.Parent.Parent.View.Responsive)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)
local HudDetail = require(script.Parent.HudDetail)

local Children = Fusion.Children
local peek = Fusion.peek

local L = Localization.get

export type Props = {
	-- Verdadeiro enquanto existe partida. Não é a rota: abrir Configurações no meio do combate
	-- troca a rota, e o HUD (com o tabuleiro dentro) precisa continuar existindo por baixo.
	visible: Fusion.UsedAs<boolean>,
	localUserId: number,
}

-- Maquete 2026-09-19: o mapa ocupa a tela inteira e o HUD flutua por cima, em quatro cantos.
-- Nada de faixa preta em cima nem doca embaixo: só fichas, a coluna de torres e as ações.
--
-- Tudo é medido em pixels da tela de referência (1280x720 no computador, 760x340 no compacto):
-- o App desenha nessa régua e escala com um UIScale, então a área útil nunca é menor que a
-- referência do modo. As medidas abaixo são escolhidas para caber na referência **exata** — é
-- nela que os cantos quase se encostam.
type Metrics = {
	margin: number,
	topHeight: number, -- faixa de botões do canto superior direito
	systemHeight: number,
	systemButton: Vector2,
	leaveWidth: number,
	towerPanelW: number,
	towerCardH: number,
	towerColumns: number, -- 1 = coluna; 2 = grade (compacto, para a doca não subir demais)
	towerPortrait: number,
	towerTitle: boolean,
	towerCost: boolean, -- o preço cabe no cartão? no compacto ele vive na barra de construção
	shortLabels: boolean, -- botões do topo só com ícone e número
	contextW: number,
	contextReserve: number,
	statusAtBottom: boolean, -- rodapé à direita (computador) ou topo à esquerda (compacto)
	statusColumns: number,
	statusRowH: number,
	statusCaption: boolean,
	showTowerLimit: boolean,
	action: Vector2,
	buildBarW: number,
	introW: number,
	pauseW: number,
	pauseMaxH: number,
	pauseButton: number,
	dockCollapsible: boolean, -- doca encolhe num botão (no compacto ela cobria o Farol)
}

local DESKTOP: Metrics = {
	margin = 16,
	topHeight = 56,
	systemHeight = 48,
	systemButton = Vector2.new(150, 44),
	leaveWidth = 110,
	towerPanelW = 152,
	towerCardH = 84,
	towerColumns = 1,
	towerPortrait = 40,
	towerTitle = true,
	towerCost = true,
	shortLabels = false,
	contextW = 330,
	contextReserve = 150,
	statusAtBottom = true,
	statusColumns = 2,
	statusRowH = 44,
	statusCaption = true,
	showTowerLimit = true,
	action = Vector2.new(240, 68),
	buildBarW = 460,
	introW = 520,
	pauseW = 420,
	pauseMaxH = 620,
	pauseButton = 50,
	dockCollapsible = false,
}

-- No compacto a coluna de torres já ocupa toda a altura da direita, então as fichas sobem para
-- o canto de cima à esquerda (o único que sobra) e perdem a legenda: o ícone já diz o que é.
local COMPACT: Metrics = {
	margin = 8,
	topHeight = 42,
	systemHeight = 34,
	systemButton = Vector2.new(66, 34),
	leaveWidth = 66,
	towerPanelW = 216,
	towerCardH = 62,
	towerColumns = 2,
	towerPortrait = 24,
	towerTitle = false,
	towerCost = false,
	shortLabels = true,
	contextW = 230,
	contextReserve = 74,
	statusAtBottom = false,
	statusColumns = 4,
	statusRowH = 34,
	statusCaption = false,
	showTowerLimit = false,
	action = Vector2.new(170, 46),
	buildBarW = 360,
	introW = 360,
	pauseW = 330,
	pauseMaxH = 268,
	pauseButton = 42,
	dockCollapsible = true,
}

local function formatNumber(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(rounded)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

-- Mesmo texto da tela de campanha: objetivo em linguagem do jogador.
local function objectiveText(objective: Types.ObjectiveDef): string
	local kind = objective.kind
	if kind == "noLeak" then
		return L("objective.noLeak")
	elseif kind == "maxDamage" then
		return L("objective.maxDamage", { value = objective.value or 0 })
	elseif kind == "maxTowers" then
		return L("objective.maxTowers", { value = objective.value or 0 })
	elseif kind == "onlyTowers" then
		local names: { string } = {}
		for _, towerId in ipairs(objective.towers or {}) do
			local def = Catalog.getTower(towerId)
			table.insert(names, if def then def.name else towerId)
		end
		return L("objective.onlyTowers", { towers = table.concat(names, " · ") })
	elseif kind == "rushAll" then
		return L("objective.rushAll")
	end
	return ""
end

-- Pílula de texto do HUD: usada para fase, limite de torres e prévia da onda.
local function pill(
	scope: Kit.Scope,
	props: {
		name: string,
		text: Kit.Used<string>,
		color: Color3?,
		textColor: Color3?,
		visible: Kit.Used<boolean>?,
		position: UDim2?,
		anchorPoint: Vector2?,
		layoutOrder: number?,
		zIndex: number?,
	}
): Frame
	local zIndex = props.zIndex or 10
	return Kit.panel(scope, {
		name = props.name,
		blocking = true,
		visible = props.visible,
		size = UDim2.new(0, 0, 0, 30),
		automaticSize = Enum.AutomaticSize.X,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		color = props.color or Theme.colors.ink,
		strokeColor = Theme.colors.inkDeep,
		radius = Kit.radius.pill,
		padding = 12,
		paddingVertical = 4,
		gloss = false,
		zIndex = zIndex,
		children = Kit.children(Kit.text(scope, {
			Text = props.text,
			TextColor3 = props.textColor or Theme.colors.cream,
			Font = Theme.fonts.bodyBold,
			TextSize = 14,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = zIndex + 1,
		})),
	})
end

return function(scope: Kit.Scope, props: Props): Frame
	local snapshot = Bridge.use(scope, Atoms.snapshot)
	local loadout = Bridge.use(scope, Atoms.loadout)
	local buildTowerId = Bridge.use(scope, Atoms.buildTowerId)
	local buildReason = Bridge.use(scope, Atoms.buildBlockedReason)
	local introStep = Bridge.use(scope, Atoms.introStep)
	local bossBanner = Bridge.use(scope, Atoms.bossBanner)
	local announce = Bridge.use(scope, Atoms.announce)
	local connection = Bridge.use(scope, Atoms.connection)
	local zoomed = Bridge.use(scope, Atoms.zoomed)
	local paused = Bridge.use(scope, Atoms.paused)
	local dockOpen = Bridge.use(scope, Atoms.buildDockOpen)

	-- Aparelho de toque decide o fluxo de construção (um toque posiciona, outro constrói).
	local touchInput = InputController.isTouchDevice()
	-- Modo lido na montagem: o App remonta a árvore inteira quando ele muda, e só a escala
	-- (que não mexe no layout) é aplicada sem remontar.
	local M: Metrics = if Responsive.isCompact() then COMPACT else DESKTOP

	local wallet = scope:Computed(function(use)
		local current = use(snapshot)
		return if current then current.wallet else 0
	end)
	local training = scope:Computed(function(use)
		local current = use(snapshot)
		return current ~= nil and current.mode == "training"
	end)

	-- ------------------------------------------------------------------
	-- Fichas de estado
	-- ------------------------------------------------------------------
	-- Saíram do canto superior esquerdo, onde cobriam a entrada do caminho, e vão para o canto
	-- inferior direito em bloco de duas linhas. Em duas linhas de propósito: em uma só, numa tela
	-- de 1280 de referência, a fileira encostava no botão de onda, que fica no centro do rodapé.
	-- No compacto o rodapé é estreito demais para as duas coisas, e as fichas sobem para o topo
	-- à esquerda (ver `Metrics`).
	local statusChips: { any } = {
		Kit.chip(scope, {
			name = "Base",
			compact = true,
			icon = "ui_base",
			caption = if M.statusCaption then L("hud.base") else nil,
			value = scope:Computed(function(use)
				local current = use(snapshot)
				local hp = if current then math.max(0, math.floor(current.baseHP)) else Balance.baseHP
				return tostring(hp) .. " / " .. tostring(Balance.baseHP)
			end),
			accent = scope:Computed(function(use)
				local current = use(snapshot)
				local hp = if current then current.baseHP else Balance.baseHP
				return if hp <= 30 then Theme.colors.danger else Theme.colors.gold
			end),
			progress = scope:Computed(function(use)
				local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
				return if current then current.baseHP / Balance.baseHP else 1
			end),
		}),
		Kit.chip(scope, {
			name = "Wave",
			compact = true,
			icon = "ui_wave",
			caption = if M.statusCaption then L("hud.wave") else nil,
			value = scope:Computed(function(use)
				local current = use(snapshot)
				if not current or current.mode == "training" then
					return "—"
				end
				return string.format("%02d / %02d", math.max(current.waveIndex, 0), current.totalWaves)
			end),
			accent = Theme.colors.cream,
		}),
		Kit.chip(scope, {
			name = "Scrap",
			compact = true,
			icon = "ui_scrap",
			caption = if M.statusCaption then L("hud.scrap") else nil,
			value = scope:Computed(function(use)
				if Kit.read(use, training) then
					return "∞"
				end
				return formatNumber(Kit.read(use, wallet))
			end),
			accent = Theme.colors.gold,
		}),
	}
	if M.showTowerLimit then
		table.insert(
			statusChips,
			pill(scope, {
				name = "Limit",
				text = scope:Computed(function(use)
					local current = use(snapshot)
					if not current then
						return ""
					end
					return L("hud.towerLimit", {
						placed = Selectors.myTowerCount(props.localUserId),
						limit = current.limits.perPlayer,
					})
				end),
				visible = scope:Computed(function(use)
					return Kit.read(use, snapshot) ~= nil
				end),
				zIndex = 10,
			})
		)
	end

	-- Quebra as fichas em linhas de `statusColumns`.
	local statusRows: { any } = {}
	local pending: { any } = {}
	local function closeRow()
		if #pending == 0 then
			return
		end
		local items = pending
		pending = {}
		table.insert(
			statusRows,
			scope:New("Frame")({
				Name = "StatusRow" .. tostring(#statusRows + 1),
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 0, M.statusRowH),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = #statusRows + 1,
				ZIndex = 10,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						HorizontalAlignment = if M.statusAtBottom
							then Enum.HorizontalAlignment.Right
							else Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					table.unpack(items)
				),
			})
		)
	end
	for index, chip in ipairs(statusChips) do
		chip.LayoutOrder = ((index - 1) % M.statusColumns) + 1
		table.insert(pending, chip)
		if #pending >= M.statusColumns then
			closeRow()
		end
	end
	closeRow()

	-- Active engole o toque: sem isso, tocar numa ficha construiria a torre na célula atrás.
	local statusCluster = scope:New("Frame")({
		Name = "Status",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = if M.statusAtBottom
			then UDim2.new(1, -M.margin, 1, -M.margin)
			else UDim2.fromOffset(M.margin, M.margin),
		AnchorPoint = if M.statusAtBottom then Vector2.new(1, 1) else Vector2.zero,
		ZIndex = 10,
		[Children] = Kit.children(
			Kit.list(scope, {
				Padding = UDim.new(0, 6),
				HorizontalAlignment = if M.statusAtBottom
					then Enum.HorizontalAlignment.Right
					else Enum.HorizontalAlignment.Left,
			}),
			table.unpack(statusRows)
		),
	})

	-- ------------------------------------------------------------------
	-- Canto superior direito: velocidade, opções e sair
	-- ------------------------------------------------------------------
	local systemCluster = scope:New("Frame")({
		Name = "System",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, M.systemHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -M.margin, 0, M.margin + 2),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 10,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 8),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Kit.button(scope, {
				name = "Speed",
				text = scope:Computed(function(use)
					local current = use(snapshot)
					local value = if current then current.speedMultiplier else 1
					return if M.shortLabels then tostring(value) .. "x" else L("hud.speed", { value = value })
				end),
				icon = "ui_speed",
				kind = scope:Computed(function(use)
					local current = use(snapshot)
					return if current and current.speedMultiplier == 2 then "primary" else "dark"
				end),
				size = UDim2.fromOffset(M.systemButton.X, M.systemButton.Y),
				layoutOrder = 1,
				zIndex = 11,
				onActivate = function()
					local current = peek(snapshot)
					if not current then
						return
					end
					GameFlow.voteSpeed(if current.speedMultiplier == 2 then 1 else 2)
				end,
			}),
			-- Opções e Sair saíram daqui: os dois moram dentro da pausa, junto com os objetivos.
			Kit.button(scope, {
				name = "Pause",
				text = if M.shortLabels then "" else L("hud.pause"),
				kind = "secondary",
				icon = "ui_settings",
				size = UDim2.fromOffset(if M.shortLabels then 48 else M.systemButton.X - 20, M.systemButton.Y),
				layoutOrder = 2,
				zIndex = 11,
				onActivate = function()
					Actions.setPaused(true)
				end,
			})
		),
	})

	-- O tabuleiro não é filho do HUD: ele mora na camada do cenário, sem área segura, para a
	-- arte do mapa sangrar até as bordas da tela. Aqui só ficam as peças que flutuam por cima.

	-- ------------------------------------------------------------------
	-- Doca de torres e ações
	-- ------------------------------------------------------------------

	local cards = scope:ForValues(loadout, function(_, innerScope: Kit.Scope, towerId: string)
		local def = Catalog.getTower(towerId)
		if not def then
			return innerScope:New("Frame")({ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
		end
		local cost = def.states.L0.cost
		local entry = Assets.get(Assets.towerKey(towerId, "L0"))
		local index = table.find(peek(loadout), towerId) or 1
		local selected = innerScope:Computed(function(use)
			return use(buildTowerId) == towerId
		end)
		local affordable = innerScope:Computed(function(use)
			local current = Kit.read(use, snapshot)
			if not current then
				return false
			end
			return current.mode == "training" or current.wallet >= cost
		end)
		return Kit.pressable(innerScope, {
			name = "Card_" .. towerId,
			size = UDim2.new(1, 0, 0, M.towerCardH),
			layoutOrder = index,
			zIndex = 11,
			onActivate = function()
				if peek(buildTowerId) == towerId then
					Actions.exitBuild()
				else
					Actions.enterBuild(towerId)
				end
			end,
			children = Kit.children(Kit.panel(innerScope, {
				name = "Card",
				size = UDim2.fromScale(1, 1),
				color = innerScope:Computed(function(use)
					if not Kit.read(use, affordable) then
						return Theme.colors.sage
					end
					return if Kit.read(use, selected) then Theme.colors.gold else Theme.colors.paper
				end),
				strokeColor = innerScope:Computed(function(use)
					return if use(selected) then Theme.colors.goldDark else Theme.colors.ink
				end),
				radius = 16,
				padding = 6,
				paddingVertical = 6,
				zIndex = 11,
				layout = Kit.list(innerScope, {
					Padding = UDim.new(0, 1),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				}),
				children = Kit.children(
					innerScope:New("ImageLabel")({
						Name = "Portrait",
						BackgroundTransparency = 1,
						Image = if entry then (entry.portrait or entry.image or "") else "",
						ImageTransparency = innerScope:Computed(function(use)
							return if use(affordable) then 0 else 0.5
						end),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.new(1, 0, 0, M.towerPortrait),
						LayoutOrder = 1,
						ZIndex = 12,
					}),
					Kit.text(innerScope, {
						Name = "Name",
						Text = def.name,
						Font = Theme.fonts.bodyBold,
						TextSize = if M.towerCardH >= 80 then 15 else 13,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextWrapped = false,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Size = UDim2.new(1, 0, 0, 17),
						LayoutOrder = 2,
						ZIndex = 12,
					}),
					Kit.caption(innerScope, {
						Name = "Cost",
						Visible = M.towerCost,
						Text = tostring(cost) .. " " .. L("common.scraps"),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextColor3 = innerScope:Computed(function(use)
							return if use(affordable) then Theme.colors.goldText else Theme.colors.danger
						end),
						Size = UDim2.new(1, 0, 0, if M.towerCost then 13 else 0),
						LayoutOrder = 3,
						ZIndex = 12,
					})
				),
				overlay = Kit.children(
					-- número do atalho de teclado, fora da fila do layout
					innerScope:New("Frame")({
						Name = "Hotkey",
						BackgroundColor3 = Theme.colors.ink,
						BorderSizePixel = 0,
						Size = UDim2.fromOffset(20, 20),
						Position = UDim2.new(1, -4, 0, 3),
						AnchorPoint = Vector2.new(1, 0),
						ZIndex = 14,
						[Children] = Kit.children(
							Kit.corner(innerScope, 9999),
							Kit.text(innerScope, {
								Text = tostring(index),
								TextColor3 = Theme.colors.cream,
								Font = Theme.fonts.numbers,
								TextSize = 12,
								TextXAlignment = Enum.TextXAlignment.Center,
								Size = UDim2.fromScale(1, 1),
								ZIndex = 15,
							})
						),
					})
				),
			})),
		})
	end)

	-- ------------------------------------------------------------------
	-- Coluna "Torres" à direita
	-- ------------------------------------------------------------------
	-- No compacto a doca vive encolhida: aberta, ela cobria justamente o Farol, no canto de
	-- baixo à direita. O botão BUILD abre, o X fecha e posicionar uma torre fecha sozinho.
	local dockVisible = scope:Computed(function(use)
		if not M.dockCollapsible then
			return true
		end
		return Kit.read(use, dockOpen)
	end)

	-- Em grade a altura é contada à mão: o painel nasce escondido (doca encolhida) e o
	-- AutomaticSize do Roblox não refaz a conta do UIGridLayout ao aparecer — a segunda fileira
	-- de torres ficava cortada.
	local dockGridSize = scope:Computed(function(use)
		local count = math.max(#Kit.read(use, loadout), 1)
		local rows = math.ceil(count / M.towerColumns)
		return UDim2.fromOffset(M.towerPanelW, 20 + rows * M.towerCardH + (rows - 1) * 6)
	end)

	local towerPanel = Kit.panel(scope, {
		name = "Towers",
		blocking = true,
		visible = dockVisible,
		size = if M.towerColumns > 1 then dockGridSize else UDim2.new(0, M.towerPanelW, 0, 0),
		automaticSize = if M.towerColumns > 1 then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		-- No computador a coluna desce a partir da faixa de cima. No compacto ela sobe a partir
		-- do rodapé: a área segura do celular come altura por cima, e ancorada embaixo a última
		-- torre nunca fica fora da tela.
		position = if M.statusAtBottom
			then UDim2.new(1, -M.margin, 0, M.topHeight + M.margin)
			else UDim2.new(1, -M.margin, 1, -M.margin),
		anchorPoint = if M.statusAtBottom then Vector2.new(1, 0) else Vector2.new(1, 1),
		color = Theme.colors.ink,
		strokeColor = Theme.colors.inkDeep,
		radius = 20,
		padding = 10,
		paddingVertical = 10,
		gloss = false,
		zIndex = 10,
		-- Uma coluna no computador; no compacto uma grade de duas, porque a área útil do celular
		-- é baixa e quatro cartões empilhados subiam até os botões do topo.
		layout = if M.towerColumns > 1
			then Kit.grid(scope, UDim2.fromOffset((M.towerPanelW - 20 - 6) / 2, M.towerCardH), 6)
			else Kit.list(scope, { Padding = UDim.new(0, 8) }),
		children = Kit.children(
			Kit.caption(scope, {
				Name = "Title",
				Visible = M.towerTitle,
				Text = L("hud.towers"),
				TextColor3 = Theme.colors.cyan,
				Font = Theme.fonts.bodyBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, if M.towerTitle then 14 else 0),
				LayoutOrder = 0,
				ZIndex = 11,
			}),
			cards
		),
		overlay = if M.dockCollapsible
			then Kit.children(Kit.button(scope, {
				name = "DockClose",
				text = "",
				icon = "ui_close",
				kind = "secondary",
				size = UDim2.fromOffset(30, 30),
				position = UDim2.new(1, 4, 0, -4),
				anchorPoint = Vector2.new(1, 1),
				zIndex = 14,
				onActivate = function()
					Actions.setBuildDockOpen(false)
					Actions.exitBuild()
				end,
			}))
			else nil,
	})

	-- Botão que substitui a doca quando ela está encolhida.
	local buildDockButton = Kit.button(scope, {
		name = "BuildDock",
		text = L("hud.buildDock"),
		icon = "ui_plus",
		kind = "primary",
		visible = scope:Computed(function(use)
			return M.dockCollapsible and not Kit.read(use, dockOpen)
		end),
		size = UDim2.fromOffset(148, 50),
		position = UDim2.new(1, -M.margin, 1, -M.margin),
		anchorPoint = Vector2.new(1, 1),
		zIndex = 10,
		onActivate = function()
			Actions.setBuildDockOpen(true)
		end,
	})

	-- ------------------------------------------------------------------
	-- Rodapé: o botão de iniciar a onda
	-- ------------------------------------------------------------------
	-- Fica no centro, e não no canto direito da maquete, porque neste mapa o Farol está
	-- justamente no canto inferior direito — o botão cobriria o que o jogador defende.
	--
	-- O botão do Pulso de Luz saiu daqui: agora o gesto é segurar no próprio Farol, que acende
	-- quando a recarga termina (BoardRenderer/BoardPresenter). O rodapé ficou com um botão só,
	-- que é o que deixa as fichas caberem à direita numa tela de 1280.
	local actionStack = scope:New("Frame")({
		Name = "Actions",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, M.action.Y + 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -M.margin),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 10,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			Kit.button(scope, {
				name = "ZoomReset",
				text = L("hud.zoomReset"),
				kind = "secondary",
				visible = zoomed,
				size = UDim2.fromOffset(if M.statusAtBottom then 150 else 120, 40),
				layoutOrder = 1,
				zIndex = 11,
				onActivate = function()
					BoardPresenter.resetZoom()
				end,
			}),
			-- Único botão verde do jogo: é o que solta a onda.
			Kit.button(scope, {
				name = "StartWave",
				text = scope:Computed(function(use)
					local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
					if not current then
						return L("hud.startWave")
					end
					for _, participant in ipairs(current.participants) do
						if participant.userId == props.localUserId and participant.ready then
							return "✓ " .. L("hud.waitingWave")
						end
					end
					return L("hud.startWave")
				end),
				sub = scope:Computed(function(use)
					local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
					if not current or #current.participants < 2 then
						return ""
					end
					local ready, total = 0, 0
					for _, participant in ipairs(current.participants) do
						if participant.connected then
							total += 1
							if participant.ready then
								ready += 1
							end
						end
					end
					return L("hud.readyCount", { ready = ready, total = total })
				end),
				icon = "ui_play",
				kind = "grass",
				textSize = 20,
				size = UDim2.fromOffset(M.action.X, M.action.Y),
				layoutOrder = 3,
				zIndex = 11,
				visible = scope:Computed(function(use)
					local current = use(snapshot)
					if not current then
						return false
					end
					return (current.phase == "Preparation" or current.phase == "Intermission")
						and current.mode ~= "training"
				end),
				onActivate = function()
					local current = peek(snapshot)
					local ready = false
					if current then
						for _, participant in ipairs(current.participants) do
							if participant.userId == props.localUserId then
								ready = participant.ready
							end
						end
					end
					GameFlow.setReady(not ready)
				end,
			})
		),
	})

	-- ------------------------------------------------------------------
	-- Barra de construção, prévia de onda, chefe, conexão e guia
	-- ------------------------------------------------------------------

	local buildBar = Kit.panel(scope, {
		name = "BuildBar",
		blocking = true,
		visible = scope:Computed(function(use)
			return use(buildTowerId) ~= nil
		end),
		size = UDim2.new(0, M.buildBarW, 0, 64),
		-- No compacto ela vai para a esquerda: centrada, encostava na doca de torres.
		position = if M.dockCollapsible
			then UDim2.new(0, M.margin, 1, -(M.margin + M.action.Y + 16))
			else UDim2.new(0.5, 0, 1, -(M.margin + M.action.Y + 16)),
		anchorPoint = if M.dockCollapsible then Vector2.new(0, 1) else Vector2.new(0.5, 1),
		padding = 12,
		paddingVertical = 8,
		zIndex = 20,
		layout = Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		children = Kit.children(
			Kit.text(scope, {
				Name = "Text",
				-- A barra é instrução, não confirmação: no computador o clique na célula já
				-- constrói; no toque, o segundo toque na mesma célula constrói.
				Text = scope:Computed(function(use)
					local reason = Kit.read(use, buildReason)
					if reason then
						return L(reason)
					end
					local towerId = Kit.read(use, buildTowerId)
					local def = if towerId then Catalog.getTower(towerId) else nil
					if not def then
						return ""
					end
					local params = { tower = def.name, cost = def.states.L0.cost }
					return if touchInput then L("build.tapTwice", params) else L("build.clickToBuild", params)
				end),
				Font = Theme.fonts.bodyMedium,
				TextSize = 15,
				Size = UDim2.new(1, -140, 1, 0),
				LayoutOrder = 1,
				ZIndex = 21,
			}),
			Kit.button(scope, {
				name = "Cancel",
				text = L("common.cancel"),
				kind = "secondary",
				size = UDim2.fromOffset(120, 46),
				layoutOrder = 2,
				zIndex = 21,
				onActivate = Actions.exitBuild,
			})
		),
	})

	local bossPanel = Kit.panel(scope, {
		name = "BossBanner",
		blocking = true,
		visible = scope:Computed(function(use)
			return use(bossBanner) ~= nil
		end),
		size = UDim2.new(0, 0, 0, 44),
		automaticSize = Enum.AutomaticSize.X,
		position = UDim2.new(0.5, 0, 0, M.topHeight + 12),
		anchorPoint = Vector2.new(0.5, 0),
		color = Theme.colors.dangerSoft,
		strokeColor = Theme.colors.danger,
		radius = Kit.radius.pill,
		padding = 18,
		paddingVertical = 8,
		zIndex = 22,
		children = Kit.children(Kit.text(scope, {
			Text = scope:Computed(function(use)
				return use(bossBanner) or ""
			end),
			TextColor3 = Theme.colors.danger,
			Font = Theme.fonts.bodyBold,
			TextSize = 18,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 23,
		})),
	})

	-- Aviso grande de uma linha: fim de onda, recompensa, estrela. Entra com um salto
	-- (mola) e some sozinho pelo relógio da interface.
	local announcePanel = Kit.panel(scope, {
		name = "Announce",
		blocking = false,
		visible = scope:Computed(function(use)
			return Kit.read(use, announce) ~= nil
		end),
		size = UDim2.new(0, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.XY,
		position = UDim2.new(0.5, 0, 0, M.topHeight + 34),
		anchorPoint = Vector2.new(0.5, 0),
		color = scope:Computed(function(use)
			local current: Atoms.Announce? = Kit.read(use, announce)
			return if current and current.tone == "warn" then Theme.colors.dangerSoft else Theme.colors.cream
		end),
		strokeColor = scope:Computed(function(use)
			local current: Atoms.Announce? = Kit.read(use, announce)
			return if current and current.tone == "warn" then Theme.colors.danger else Theme.colors.goldDark
		end),
		radius = Kit.radius.pill,
		padding = 26,
		paddingVertical = 10,
		zIndex = 26,
		layout = Kit.list(scope, {
			Padding = UDim.new(0, 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		children = Kit.children(
			Kit.text(scope, {
				Name = "Text",
				Text = scope:Computed(function(use)
					local current: Atoms.Announce? = Kit.read(use, announce)
					return if current then current.text else ""
				end),
				TextColor3 = scope:Computed(function(use)
					local current: Atoms.Announce? = Kit.read(use, announce)
					return if current and current.tone == "warn" then Theme.colors.danger else Theme.colors.ink
				end),
				Font = Theme.fonts.title,
				TextSize = 30,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				LayoutOrder = 1,
				ZIndex = 27,
			}),
			Kit.caption(scope, {
				Name = "Sub",
				Text = scope:Computed(function(use)
					local current: Atoms.Announce? = Kit.read(use, announce)
					return if current and current.sub then current.sub else ""
				end),
				Visible = scope:Computed(function(use)
					local current: Atoms.Announce? = Kit.read(use, announce)
					return current ~= nil and current.sub ~= nil
				end),
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				LayoutOrder = 2,
				ZIndex = 27,
			})
		),
	})
	-- salto de entrada: a escala acompanha o "at" do aviso
	do
		local target = scope:Computed(function(use)
			return if Kit.read(use, announce) ~= nil then 1 else 0.6
		end)
		local spring = scope:Spring(target, 18, 0.6)
		local scale = scope:New("UIScale")({ Scale = spring })
		scale.Parent = announcePanel
	end

	local connectionBanner = Kit.panel(scope, {
		name = "Connection",
		blocking = true,
		visible = scope:Computed(function(use)
			return use(connection) ~= "ok"
		end),
		size = UDim2.new(0, 0, 0, 38),
		automaticSize = Enum.AutomaticSize.X,
		position = UDim2.new(0.5, 0, 0, M.topHeight + 62),
		anchorPoint = Vector2.new(0.5, 0),
		color = Theme.colors.ink,
		strokeColor = Theme.colors.cyan,
		radius = Kit.radius.pill,
		padding = 16,
		paddingVertical = 6,
		gloss = false,
		zIndex = 22,
		children = Kit.children(Kit.text(scope, {
			Text = scope:Computed(function(use)
				local state = use(connection)
				return if state == "reconciling" then L("connection.reconciling") else L("connection.unstable")
			end),
			TextColor3 = Theme.colors.cyan,
			Font = Theme.fonts.bodyBold,
			TextSize = 14,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 23,
		})),
	})

	-- Guia da primeira fase: uma linha por passo, sem botão nenhum. Ele avança quando o jogador
	-- faz a ação (escolher a torre, posicionar, chamar a onda) e some com a primeira horda.
	local introCard = Kit.panel(scope, {
		name = "Intro",
		blocking = false,
		visible = scope:Computed(function(use)
			return Kit.read(use, introStep) ~= nil
		end),
		-- largura fixa e centrado: com largura automática o quadro ancorado no meio encostava
		-- na esquerda em vez de ficar no centro do rodapé
		size = UDim2.new(0, M.introW, 0, 56),
		position = UDim2.new(0.5, 0, 1, -(M.margin + M.action.Y + 20)),
		anchorPoint = Vector2.new(0.5, 1),
		color = Theme.colors.cream,
		strokeColor = Theme.colors.gold,
		radius = Kit.radius.pill,
		padding = 22,
		paddingVertical = 10,
		zIndex = 26,
		children = Kit.children(Kit.text(scope, {
			Name = "Text",
			Text = scope:Computed(function(use)
				local step = Kit.read(use, introStep)
				if step == 1 then
					return "👉 " .. L("intro.pickTower")
				elseif step == 2 then
					return "👉 " .. L("intro.placeTower")
				elseif step == 3 then
					return "👇 " .. L("intro.startWave")
				end
				return ""
			end),
			Font = Theme.fonts.bodyBold,
			TextSize = 20,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 27,
		})),
	})

	-- Objetivos da fase: as três estrelas com o estado atual, lidas do snapshot.
	-- Os objetivos moraram no canto inferior esquerdo até 20/09. Agora são conteúdo da pausa:
	-- é onde o jogador para para olhar, e o canto do tabuleiro fica livre.
	local objectivesPanel = Kit.panel(scope, {
		name = "Objectives",
		blocking = true,
		visible = scope:Computed(function(use)
			local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
			return current ~= nil and current.levelId ~= nil
		end),
		size = UDim2.new(1, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = 2,
		color = Theme.colors.ink,
		strokeColor = Theme.colors.inkDeep,
		radius = 16,
		padding = 12,
		paddingVertical = 10,
		gloss = false,
		zIndex = 18,
		layout = Kit.list(scope, { Padding = UDim.new(0, 4) }),
		children = Kit.children(
			Kit.caption(scope, {
				Name = "Title",
				Text = L("campaign.objectives"),
				TextColor3 = Theme.colors.cyan,
				Font = Theme.fonts.bodyBold,
				TextSize = 11,
				Size = UDim2.new(1, 0, 0, 13),
				LayoutOrder = 1,
				ZIndex = 19,
			}),
			Kit.text(scope, {
				Name = "Lines",
				Text = scope:Computed(function(use)
					local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
					if not current or not current.levelId then
						return ""
					end
					local level = Catalog.getLevel(current.levelId)
					if not level then
						return ""
					end
					local lines: { string } = { "★ " .. L("objective.clear") }
					local stats: Types.CampaignStats = {
						damageTaken = current.damageTaken,
						towersBuilt = current.towersBuilt,
						towerIds = {},
						wavesRushed = current.wavesRushed,
						wavesTotal = current.totalWaves,
					}
					for _, objective in ipairs(level.objectives) do
						-- "só estas torres" não dá para conferir ao vivo (o fio não manda a lista),
						-- então ela aparece sem marca até o fim da partida
						local live = objective.kind ~= "onlyTowers" and Stars.objectiveMet(objective, stats)
						local mark = if live then "★" else "☆"
						table.insert(lines, mark .. " " .. objectiveText(objective))
					end
					return table.concat(lines, "\n")
				end),
				TextColor3 = Theme.colors.cream,
				TextSize = 13,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				ZIndex = 19,
			})
		),
	})

	-- ------------------------------------------------------------------
	-- Pausa
	-- ------------------------------------------------------------------
	-- Cortina por cima do HUD com os objetivos, as configurações e a saída. **Não** para a
	-- simulação: o combate é do servidor e, em grupo, parar seria parar o jogo dos outros. É a
	-- tela do jogador que para — por isso o aviso escrito no cartão.
	local pauseOverlay = scope:New("Frame")({
		Name = "PauseOverlay",
		Active = true, -- engole o toque: nada passa para o tabuleiro enquanto a pausa está aberta
		BackgroundColor3 = Theme.colors.inkDeep,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = paused,
		ZIndex = 40,
		-- O cartão vive dentro de um rolável: em tela de celular a lista (objetivos + três
		-- botões) passa da altura útil, e sem isto o título e o "Sair" ficavam cortados.
		-- O rolável cresce com o cartão até o teto do modo e só então rola: assim ele fica
		-- centrado quando cabe (computador) e não corta título nem "Sair" quando não cabe.
		[Children] = Kit.children(Kit.scroller(scope, {
			Name = "PauseScroll",
			Size = UDim2.fromOffset(M.pauseW + 16, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ScrollBarThickness = 4,
			ZIndex = 41,
			[Children] = Kit.children(
				scope:New("UISizeConstraint")({
					MaxSize = Vector2.new(M.pauseW + 16, M.pauseMaxH),
				}),
				Kit.list(scope, {
					Padding = UDim.new(0, 0),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Top,
				}),
				Kit.panel(scope, {
					name = "PauseCard",
					blocking = true,
					size = UDim2.new(0, M.pauseW, 0, 0),
					automaticSize = Enum.AutomaticSize.Y,
					color = Theme.colors.ink,
					strokeColor = Theme.colors.inkDeep,
					radius = 22,
					padding = 16,
					paddingVertical = 14,
					zIndex = 42,
					layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
					children = Kit.children(
						Kit.title(scope, {
							Text = L("hud.pause"),
							-- cartão escuro: o título precisa da tinta clara (o padrão do Kit é tinta escura)
							TextColor3 = Theme.colors.cream,
							TextSize = 24,
							TextXAlignment = Enum.TextXAlignment.Center,
							Size = UDim2.new(1, 0, 0, 28),
							LayoutOrder = 1,
							ZIndex = 42,
						}),
						objectivesPanel,
						Kit.caption(scope, {
							-- no compacto a altura é curta: o aviso sai e sobra espaço para os botões
							Visible = not M.dockCollapsible,
							Text = L("hud.pauseNotice"),
							TextXAlignment = Enum.TextXAlignment.Center,
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							LayoutOrder = 3,
							ZIndex = 42,
						}),
						Kit.button(scope, {
							name = "Resume",
							text = L("hud.pauseResume"),
							kind = "grass",
							icon = "ui_play",
							size = UDim2.new(1, 0, 0, M.pauseButton + 6),
							layoutOrder = 4,
							zIndex = 42,
							onActivate = function()
								Actions.setPaused(false)
							end,
						}),
						Kit.button(scope, {
							name = "Options",
							text = L("hud.options"),
							kind = "secondary",
							icon = "ui_settings",
							size = UDim2.new(1, 0, 0, M.pauseButton),
							layoutOrder = 5,
							zIndex = 42,
							onActivate = function()
								-- a partida continua atrás: Configurações é uma tela por cima do HUD
								Actions.push("settings")
							end,
						}),
						Kit.button(scope, {
							name = "Leave",
							text = L("hud.leave"),
							kind = "danger",
							size = UDim2.new(1, 0, 0, M.pauseButton),
							layoutOrder = 6,
							zIndex = 42,
							onActivate = function()
								Actions.setPaused(false)
								GameFlow.confirmLeave()
							end,
						})
					),
				})
			),
		})),
	})

	local trainingPanel = Kit.panel(scope, {
		name = "Training",
		blocking = true,
		visible = training,
		size = UDim2.new(1, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = 3,
		padding = 16,
		zIndex = 20,
		layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
		children = Kit.children(
			Kit.caption(scope, {
				Text = L("hud.trainingNotice"),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				ZIndex = 21,
			}),
			Kit.button(scope, {
				name = "Spawn1",
				text = L("hud.trainingSpawn1"),
				kind = "secondary",
				size = UDim2.new(1, 0, 0, 44),
				layoutOrder = 2,
				zIndex = 21,
				onActivate = function()
					GameFlow.trainingSpawn("fiapo", 1)
				end,
			}),
			Kit.button(scope, {
				name = "Spawn10",
				text = L("hud.trainingSpawn10"),
				kind = "secondary",
				size = UDim2.new(1, 0, 0, 44),
				layoutOrder = 3,
				zIndex = 21,
				onActivate = function()
					GameFlow.trainingSpawn("fiapo", 10)
				end,
			}),
			Kit.button(scope, {
				name = "Clear",
				text = L("hud.trainingClear"),
				kind = "danger",
				size = UDim2.new(1, 0, 0, 44),
				layoutOrder = 4,
				zIndex = 21,
				onActivate = GameFlow.trainingClear,
			})
		),
	})

	-- Coluna de contexto no canto inferior esquerdo: objetivos, detalhe da torre e treino nunca
	-- se cobrem, porque são itens de uma fila vertical em vez de três painéis no mesmo canto.
	local contextColumn = Kit.scroller(scope, {
		Name = "SidePanels",
		-- rola quando objetivos + detalhe passam da altura livre, em vez de subir até as fichas
		Size = UDim2.new(0, M.contextW, 1, -(M.topHeight + M.contextReserve)),
		Position = UDim2.new(0, M.margin, 1, -M.margin),
		AnchorPoint = Vector2.new(0, 1),
		ScrollBarThickness = 4,
		ZIndex = 18,
		[Children] = Kit.children(
			Kit.list(scope, {
				Padding = UDim.new(0, 10),
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			introCard,
			HudDetail(scope, { localUserId = props.localUserId }),
			trainingPanel
		),
	})

	return scope:New("Frame")({
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible,
		[Children] = Kit.children(
			statusCluster,
			systemCluster,
			towerPanel,
			buildDockButton,
			actionStack,
			buildBar,
			announcePanel,
			bossPanel,
			connectionBanner,
			contextColumn,
			pauseOverlay
		),
	})
end
