--!strict
-- HUD de combate. Faixa superior com fichas, área do tabuleiro, doca de torres e os painéis
-- contextuais (construção, tutorial, chefe, conexão).
--
-- Tudo é leitura dos átomos: o HUD não guarda estado de partida nem decide preço, dano ou
-- resultado. Quando um botão é apertado, quem fala com o servidor é Controllers/GameFlow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local BoardPresenter = require(script.Parent.Parent.Parent.Controllers.BoardPresenter)
local InputController = require(script.Parent.Parent.Parent.Controllers.InputController)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
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
local TOP_HEIGHT = 56 -- altura das fichas do canto superior esquerdo
local TOWER_PANEL_W = 152 -- coluna "Torres" à direita
local TOWER_CARD_H = 84
local CONTEXT_W = 330 -- coluna de contexto no canto inferior esquerdo

local function formatNumber(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(rounded)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function phaseLabel(snapshot: Types.MatchSnapshot?): string
	if not snapshot then
		return ""
	end
	local remaining = snapshot.phaseEndsAt - snapshot.simTime
	if snapshot.phase == "Preparation" then
		if snapshot.phaseEndsAt == math.huge then
			return L("hud.ready") .. " →"
		end
		return L("hud.preparation", { seconds = math.max(0, math.ceil(remaining)) })
	elseif snapshot.phase == "Intermission" then
		if snapshot.phaseEndsAt == math.huge then
			return L("hud.ready") .. " →"
		end
		return L("hud.intermission", { seconds = math.max(0, math.ceil(remaining)) })
	end
	return ""
end

local function wavePreviewText(snapshot: Types.MatchSnapshot?): string
	if not snapshot or not snapshot.nextWavePreview or #snapshot.nextWavePreview == 0 then
		return ""
	end
	local parts: { string } = {}
	for _, group in ipairs(snapshot.nextWavePreview) do
		table.insert(parts, tostring(group.count) .. "× " .. L("enemy." .. group.enemy))
	end
	return L("hud.nextWave") .. ": " .. table.concat(parts, ", ")
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
	local buildCell = Bridge.use(scope, Atoms.buildCell)
	local buildReason = Bridge.use(scope, Atoms.buildBlockedReason)
	local tutorialStep = Bridge.use(scope, Atoms.tutorialStep)
	local tutorialOpen = Bridge.use(scope, Atoms.tutorialOpen)
	local bossBanner = Bridge.use(scope, Atoms.bossBanner)
	local announce = Bridge.use(scope, Atoms.announce)
	local connection = Bridge.use(scope, Atoms.connection)
	local zoomed = Bridge.use(scope, Atoms.zoomed)

	-- Aparelho de toque decide o fluxo de construção (um toque posiciona, outro constrói).
	local touchInput = InputController.isTouchDevice()

	local wallet = scope:Computed(function(use)
		local current = use(snapshot)
		return if current then current.wallet else 0
	end)
	local training = scope:Computed(function(use)
		local current = use(snapshot)
		return current ~= nil and current.mode == "training"
	end)

	-- ------------------------------------------------------------------
	-- Canto superior esquerdo: fichas de estado
	-- ------------------------------------------------------------------
	-- Active engole o toque: sem isso, tocar numa ficha construiria a torre na célula atrás.
	local statusCluster = scope:New("Frame")({
		Name = "Status",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, TOP_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(16, 14),
		ZIndex = 10,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Kit.chip(scope, {
				name = "Base",
				icon = "ui_base",
				caption = L("hud.base"),
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
				layoutOrder = 1,
			}),
			Kit.chip(scope, {
				name = "Wave",
				icon = "ui_wave",
				caption = L("hud.wave"),
				value = scope:Computed(function(use)
					local current = use(snapshot)
					if not current or current.mode == "training" then
						return "—"
					end
					return string.format("%02d / %02d", math.max(current.waveIndex, 0), current.totalWaves)
				end),
				accent = Theme.colors.cream,
				layoutOrder = 2,
			}),
			Kit.chip(scope, {
				name = "Scrap",
				icon = "ui_scrap",
				caption = L("hud.scrap"),
				value = scope:Computed(function(use)
					if Kit.read(use, training) then
						return "∞"
					end
					return formatNumber(Kit.read(use, wallet))
				end),
				accent = Theme.colors.gold,
				layoutOrder = 3,
			}),
			pill(scope, {
				name = "Phase",
				text = scope:Computed(function(use)
					return phaseLabel(use(snapshot))
				end),
				textColor = Theme.colors.cyan,
				visible = scope:Computed(function(use)
					return phaseLabel(Kit.read(use, snapshot)) ~= ""
				end),
				layoutOrder = 4,
				zIndex = 10,
			}),
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
				layoutOrder = 5,
				zIndex = 10,
			})
		),
	})

	-- ------------------------------------------------------------------
	-- Canto superior direito: velocidade, opções e sair
	-- ------------------------------------------------------------------
	local systemCluster = scope:New("Frame")({
		Name = "System",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -16, 0, 18),
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
					return L("hud.speed", { value = if current then current.speedMultiplier else 1 })
				end),
				icon = "ui_speed",
				kind = scope:Computed(function(use)
					local current = use(snapshot)
					return if current and current.speedMultiplier == 2 then "primary" else "dark"
				end),
				size = UDim2.fromOffset(150, 44),
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
			Kit.button(scope, {
				name = "Options",
				text = L("hud.options"),
				kind = "secondary",
				icon = "ui_settings",
				size = UDim2.fromOffset(140, 44),
				layoutOrder = 2,
				zIndex = 11,
				onActivate = function()
					-- a partida continua rodando atrás: Configurações é uma tela por cima do HUD
					Actions.push("settings")
				end,
			}),
			Kit.button(scope, {
				name = "Leave",
				text = L("hud.leave"),
				kind = "danger",
				size = UDim2.fromOffset(110, 44),
				layoutOrder = 3,
				zIndex = 11,
				onActivate = GameFlow.confirmLeave,
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
			size = UDim2.new(1, 0, 0, TOWER_CARD_H),
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
						Size = UDim2.new(1, 0, 0, 40),
						LayoutOrder = 1,
						ZIndex = 12,
					}),
					Kit.text(innerScope, {
						Name = "Name",
						Text = def.name,
						Font = Theme.fonts.bodyBold,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextWrapped = false,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Size = UDim2.new(1, 0, 0, 17),
						LayoutOrder = 2,
						ZIndex = 12,
					}),
					Kit.caption(innerScope, {
						Name = "Cost",
						Text = tostring(cost) .. " " .. L("common.scraps"),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextColor3 = innerScope:Computed(function(use)
							return if use(affordable) then Theme.colors.goldText else Theme.colors.danger
						end),
						Size = UDim2.new(1, 0, 0, 13),
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
	local towerPanel = Kit.panel(scope, {
		name = "Towers",
		blocking = true,
		size = UDim2.new(0, TOWER_PANEL_W, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		position = UDim2.new(1, -16, 0, TOP_HEIGHT + 28),
		anchorPoint = Vector2.new(1, 0),
		color = Theme.colors.ink,
		strokeColor = Theme.colors.inkDeep,
		radius = 20,
		padding = 10,
		paddingVertical = 10,
		gloss = false,
		zIndex = 10,
		layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
		children = Kit.children(
			Kit.caption(scope, {
				Name = "Title",
				Text = L("hud.towers"),
				TextColor3 = Theme.colors.cyan,
				Font = Theme.fonts.bodyBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 0,
				ZIndex = 11,
			}),
			cards
		),
	})

	-- ------------------------------------------------------------------
	-- Rodapé: pulso e o botão de iniciar a onda
	-- ------------------------------------------------------------------
	-- Fica no centro, e não no canto direito da maquete, porque neste mapa o Farol está
	-- justamente no canto inferior direito — o botão cobriria o que o jogador defende.
	local actionStack = scope:New("Frame")({
		Name = "Actions",
		Active = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 72),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -16),
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
				size = UDim2.fromOffset(150, 40),
				layoutOrder = 1,
				zIndex = 11,
				onActivate = function()
					BoardPresenter.resetZoom()
				end,
			}),
			Kit.button(scope, {
				name = "Pulse",
				text = L("hud.pulse"),
				icon = "ui_pulse",
				kind = "cyan",
				size = UDim2.fromOffset(200, 56),
				layoutOrder = 2,
				zIndex = 11,
				visible = scope:Computed(function(use)
					return not use(training)
				end),
				disabled = scope:Computed(function(use)
					local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
					if not current then
						return true
					end
					return current.phase ~= "Wave" or current.simTime < current.pulseReadyAt
				end),
				sub = scope:Computed(function(use)
					local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
					if not current then
						return ""
					end
					if current.simTime < current.pulseReadyAt then
						return L("hud.pulseCooldown", {
							seconds = math.max(0, math.ceil(current.pulseReadyAt - current.simTime)),
						})
					end
					return L("hud.pulseReady")
				end),
				onActivate = GameFlow.pulse,
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
				size = UDim2.fromOffset(240, 68),
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
	-- Barra de construção, prévia de onda, chefe, conexão e tutorial
	-- ------------------------------------------------------------------

	local buildBar = Kit.panel(scope, {
		name = "BuildBar",
		blocking = true,
		visible = scope:Computed(function(use)
			return use(buildTowerId) ~= nil
		end),
		size = UDim2.new(0, if touchInput then 560 else 460, 0, 64),
		position = UDim2.new(0.5, 0, 1, -100),
		anchorPoint = Vector2.new(0.5, 1),
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
				Size = UDim2.new(1, if touchInput then -320 else -140, 1, 0),
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
			}),
			-- O botão de confirmar só existe no toque, como alternativa ao segundo toque.
			Kit.button(scope, {
				name = "Confirm",
				text = scope:Computed(function(use)
					local towerId = Kit.read(use, buildTowerId)
					local def = if towerId then Catalog.getTower(towerId) else nil
					local cost = if def then def.states.L0.cost else 0
					return L("build.confirm", { cost = cost })
				end),
				kind = "primary",
				visible = touchInput,
				disabled = scope:Computed(function(use)
					return Kit.read(use, buildCell) == nil or Kit.read(use, buildReason) ~= nil
				end),
				size = UDim2.fromOffset(180, 46),
				layoutOrder = 3,
				zIndex = 21,
				onActivate = function()
					local towerId = peek(buildTowerId)
					local cell = peek(buildCell)
					if towerId and cell then
						GameFlow.placeTower(towerId, cell[1], cell[2])
					end
				end,
			})
		),
	})

	local wavePreview = Kit.panel(scope, {
		name = "WavePreview",
		blocking = true,
		visible = scope:Computed(function(use)
			return wavePreviewText(Kit.read(use, snapshot)) ~= "" and not Kit.read(use, tutorialOpen)
		end),
		size = UDim2.new(0, 0, 0, 34),
		automaticSize = Enum.AutomaticSize.X,
		-- item da coluna de contexto (canto inferior esquerdo): em cima do tabuleiro ela brigava
		-- com as fichas e com a contagem desenhada na entrada do caminho
		layoutOrder = 4,
		color = Theme.colors.cream,
		radius = Kit.radius.pill,
		padding = 14,
		paddingVertical = 6,
		zIndex = 15,
		children = Kit.children(Kit.text(scope, {
			Text = scope:Computed(function(use)
				return wavePreviewText(use(snapshot))
			end),
			TextSize = 14,
			Font = Theme.fonts.bodyMedium,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 16,
		})),
	})

	local bossPanel = Kit.panel(scope, {
		name = "BossBanner",
		blocking = true,
		visible = scope:Computed(function(use)
			return use(bossBanner) ~= nil
		end),
		size = UDim2.new(0, 0, 0, 44),
		automaticSize = Enum.AutomaticSize.X,
		position = UDim2.new(0.5, 0, 0, TOP_HEIGHT + 12),
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

	-- Aviso grande de uma linha: fim de onda, recompensa, marco do tutorial. Entra com um salto
	-- (mola) e some sozinho pelo relógio da interface.
	local announcePanel = Kit.panel(scope, {
		name = "Announce",
		blocking = false,
		visible = scope:Computed(function(use)
			return Kit.read(use, announce) ~= nil
		end),
		size = UDim2.new(0, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.XY,
		position = UDim2.new(0.5, 0, 0, TOP_HEIGHT + 34),
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
		position = UDim2.new(0.5, 0, 0, TOP_HEIGHT + 62),
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

	local tutorialCard = Kit.panel(scope, {
		name = "Tutorial",
		blocking = true,
		visible = scope:Computed(function(use)
			return Kit.read(use, tutorialStep) ~= nil and Kit.read(use, tutorialOpen)
		end),
		size = UDim2.new(1, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = 1,
		color = Theme.colors.cream,
		padding = 16,
		zIndex = 24,
		layout = Kit.list(scope, { Padding = UDim.new(0, 10) }),
		children = Kit.children(
			Kit.text(scope, {
				Name = "Text",
				Text = scope:Computed(function(use)
					local step = use(tutorialStep)
					return if step then L("tutorial.step" .. tostring(step)) else ""
				end),
				Font = Theme.fonts.bodyMedium,
				TextSize = 15,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				ZIndex = 25,
			}),
			scope:New("Frame")({
				Name = "Actions",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 48),
				LayoutOrder = 2,
				ZIndex = 25,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "Next",
						text = scope:Computed(function(use)
							local step = use(tutorialStep)
							return if step and step >= 6 then L("tutorial.done") else L("tutorial.next")
						end),
						kind = "primary",
						size = UDim2.fromOffset(150, 44),
						layoutOrder = 1,
						zIndex = 26,
						onActivate = function()
							local step = peek(tutorialStep)
							-- na última etapa o botão encerra o tutorial; nas outras só fecha o cartão
							if step and step >= 6 then
								GameFlow.leaveMatch()
							else
								Actions.dismissTutorial()
							end
						end,
					}),
					Kit.button(scope, {
						name = "Skip",
						text = L("tutorial.skip"),
						kind = "ghost",
						size = UDim2.fromOffset(140, 44),
						layoutOrder = 2,
						zIndex = 26,
						onActivate = GameFlow.tutorialSkip,
					})
				),
			})
		),
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

	-- Coluna de contexto no canto inferior esquerdo: tutorial, detalhe da torre e treino nunca
	-- se cobrem, porque são itens de uma fila vertical em vez de três painéis no mesmo canto.
	local contextColumn = Kit.scroller(scope, {
		Name = "SidePanels",
		-- rola quando tutorial + detalhe passam da altura livre, em vez de subir até as fichas
		Size = UDim2.new(0, CONTEXT_W, 1, -(TOP_HEIGHT + 120)),
		Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		ScrollBarThickness = 4,
		ZIndex = 18,
		[Children] = Kit.children(
			Kit.list(scope, {
				Padding = UDim.new(0, 10),
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			tutorialCard,
			HudDetail(scope, { localUserId = props.localUserId }),
			trainingPanel,
			wavePreview
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
			actionStack,
			buildBar,
			announcePanel,
			bossPanel,
			connectionBanner,
			contextColumn
		),
	})
end
