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
	-- Preenchido pelo App: é aqui que o tabuleiro (renderizador imperativo) é montado.
	onBoardArea: (Frame) -> (),
}

local TOP_HEIGHT = 64
local DOCK_HEIGHT = 116

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

return function(scope: Kit.Scope, props: Props): Frame
	local snapshot = Bridge.use(scope, Atoms.snapshot)
	local loadout = Bridge.use(scope, Atoms.loadout)
	local buildTowerId = Bridge.use(scope, Atoms.buildTowerId)
	local buildCell = Bridge.use(scope, Atoms.buildCell)
	local buildReason = Bridge.use(scope, Atoms.buildBlockedReason)
	local tutorialStep = Bridge.use(scope, Atoms.tutorialStep)
	local tutorialOpen = Bridge.use(scope, Atoms.tutorialOpen)
	local bossBanner = Bridge.use(scope, Atoms.bossBanner)
	local connection = Bridge.use(scope, Atoms.connection)
	local zoomed = Bridge.use(scope, Atoms.zoomed)

	local wallet = scope:Computed(function(use)
		local current = use(snapshot)
		return if current then current.wallet else 0
	end)
	local training = scope:Computed(function(use)
		local current = use(snapshot)
		return current ~= nil and current.mode == "training"
	end)

	-- ------------------------------------------------------------------
	-- Faixa superior
	-- ------------------------------------------------------------------

	local topBar = Kit.panel(scope, {
		name = "TopBar",
		blocking = true,
		size = UDim2.new(1, -32, 0, TOP_HEIGHT),
		position = UDim2.fromOffset(16, 12),
		color = Theme.colors.ink,
		strokeColor = Theme.colors.inkDeep,
		radius = 18,
		padding = 12,
		paddingVertical = 6,
		gloss = false,
		zIndex = 10,
		layout = Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		children = Kit.children(
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
			Kit.text(scope, {
				Name = "Phase",
				Text = scope:Computed(function(use)
					return phaseLabel(use(snapshot))
				end),
				TextColor3 = Theme.colors.cream,
				Font = Theme.fonts.bodyMedium,
				TextSize = 16,
				Size = UDim2.new(0, 190, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 3,
				ZIndex = 12,
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
				layoutOrder = 4,
			}),
			Kit.text(scope, {
				Name = "Limit",
				Text = scope:Computed(function(use)
					local current = use(snapshot)
					if not current then
						return ""
					end
					return L("hud.towerLimit", {
						placed = Selectors.myTowerCount(props.localUserId),
						limit = current.limits.perPlayer,
					})
				end),
				TextColor3 = Theme.colors.cream,
				TextSize = 14,
				Size = UDim2.new(0, 150, 1, 0),
				LayoutOrder = 5,
				ZIndex = 12,
			}),
			Kit.button(scope, {
				name = "Options",
				text = L("hud.options"),
				kind = "secondary",
				icon = "ui_settings",
				size = UDim2.fromOffset(160, 48),
				layoutOrder = 6,
				zIndex = 12,
				onActivate = function()
					-- a partida continua rodando atrás: Configurações é uma tela por cima do HUD
					Actions.push("settings")
				end,
			}),
			Kit.button(scope, {
				name = "Leave",
				text = L("hud.leave"),
				kind = "danger",
				size = UDim2.fromOffset(120, 48),
				layoutOrder = 7,
				zIndex = 12,
				onActivate = GameFlow.confirmLeave,
			})
		),
	})
	-- a ficha de opções encosta na direita: o espaço livre fica no meio da faixa
	local topLayout = topBar:FindFirstChild("Surface")
	if topLayout then
		local limitLabel = (topLayout :: Frame):FindFirstChild("Limit")
		if limitLabel and limitLabel:IsA("TextLabel") then
			limitLabel.Size = UDim2.new(1, -1040, 1, 0)
		end
	end

	-- ------------------------------------------------------------------
	-- Área do tabuleiro (o renderizador imperativo é montado aqui pelo App)
	-- ------------------------------------------------------------------

	local boardArea = scope:New("Frame")({
		Name = "BoardArea",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -332, 1, -(TOP_HEIGHT + DOCK_HEIGHT + 44)),
		Position = UDim2.fromOffset(16, TOP_HEIGHT + 24),
		ZIndex = 5,
	})
	props.onBoardArea(boardArea)

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
			size = UDim2.fromOffset(112, DOCK_HEIGHT - 12),
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
				padding = 8,
				paddingVertical = 6,
				zIndex = 11,
				layout = Kit.list(innerScope, {
					Padding = UDim.new(0, 2),
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
						Size = UDim2.new(1, 0, 0, 46),
						LayoutOrder = 1,
						ZIndex = 12,
					}),
					Kit.text(scope, {
						Name = "Name",
						Text = def.name,
						Font = Theme.fonts.bodyBold,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextWrapped = false,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Size = UDim2.new(1, 0, 0, 18),
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
						Size = UDim2.new(1, 0, 0, 14),
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
						Size = UDim2.fromOffset(22, 22),
						Position = UDim2.new(1, -6, 0, 4),
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

	local dock = Kit.panel(scope, {
		name = "Dock",
		blocking = true,
		size = UDim2.new(1, -32, 0, DOCK_HEIGHT),
		position = UDim2.new(0, 16, 1, -(DOCK_HEIGHT + 12)),
		color = Theme.colors.ink,
		strokeColor = Theme.colors.inkDeep,
		radius = 20,
		padding = 10,
		paddingVertical = 6,
		gloss = false,
		zIndex = 10,
		layout = Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		children = Kit.children(
			scope:New("Frame")({
				Name = "Cards",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -640, 1, 0),
				LayoutOrder = 1,
				ZIndex = 11,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					cards
				),
			}),
			Kit.button(scope, {
				name = "Pulse",
				text = L("hud.pulse"),
				icon = "ui_pulse",
				kind = "cyan",
				size = UDim2.fromOffset(200, DOCK_HEIGHT - 24),
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
			Kit.button(scope, {
				name = "Speed",
				text = scope:Computed(function(use)
					local current = use(snapshot)
					return L("hud.speed", { value = if current then current.speedMultiplier else 1 })
				end),
				sub = L("hud.speedHint"),
				icon = "ui_speed",
				kind = scope:Computed(function(use)
					local current = use(snapshot)
					return if current and current.speedMultiplier == 2 then "primary" else "dark"
				end),
				size = UDim2.fromOffset(190, DOCK_HEIGHT - 24),
				layoutOrder = 3,
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
				name = "Ready",
				text = scope:Computed(function(use)
					local current: Types.MatchSnapshot? = Kit.read(use, snapshot)
					if not current then
						return L("hud.ready")
					end
					for _, participant in ipairs(current.participants) do
						if participant.userId == props.localUserId and participant.ready then
							return "✓ " .. L("hud.ready")
						end
					end
					return L("hud.ready")
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
				kind = "primary",
				size = UDim2.fromOffset(200, DOCK_HEIGHT - 24),
				layoutOrder = 4,
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
		size = UDim2.new(0, 560, 0, 64),
		position = UDim2.new(0.5, 0, 1, -(DOCK_HEIGHT + 28)),
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
				Text = scope:Computed(function(use)
					local reason = Kit.read(use, buildReason)
					if reason then
						return L(reason)
					end
					if Kit.read(use, buildCell) == nil then
						return L("build.pickCell")
					end
					return L("build.noCircuit")
				end),
				Font = Theme.fonts.bodyMedium,
				TextSize = 15,
				Size = UDim2.new(1, -300, 1, 0),
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
			Kit.button(scope, {
				name = "Confirm",
				text = scope:Computed(function(use)
					local towerId = Kit.read(use, buildTowerId)
					local def = if towerId then Catalog.getTower(towerId) else nil
					local cost = if def then def.states.L0.cost else 0
					return L("build.confirm", { cost = cost })
				end),
				kind = "primary",
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
		position = UDim2.fromOffset(24, TOP_HEIGHT + 28),
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
		position = UDim2.new(0.5, 0, 0, TOP_HEIGHT + 28),
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

	local connectionBanner = Kit.panel(scope, {
		name = "Connection",
		blocking = true,
		visible = scope:Computed(function(use)
			return use(connection) ~= "ok"
		end),
		size = UDim2.new(0, 0, 0, 38),
		automaticSize = Enum.AutomaticSize.X,
		position = UDim2.new(0.5, 0, 0, TOP_HEIGHT + 80),
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

	local zoomReset = Kit.button(scope, {
		name = "ZoomReset",
		text = L("hud.zoomReset"),
		kind = "secondary",
		visible = zoomed,
		size = UDim2.fromOffset(150, 44),
		position = UDim2.new(0, 24, 1, -(DOCK_HEIGHT + 28)),
		anchorPoint = Vector2.new(0, 1),
		zIndex = 19,
		onActivate = function()
			BoardPresenter.resetZoom()
		end,
	})

	-- Coluna de contexto: tutorial, detalhe da torre e treino nunca se cobrem, porque são itens
	-- de uma fila vertical em vez de três painéis ancorados no mesmo canto.
	local sideColumn = Kit.scroller(scope, {
		Name = "SidePanels",
		-- rola quando tutorial + detalhe passam da altura livre, em vez de invadir a doca
		Size = UDim2.new(0, 312, 1, -(TOP_HEIGHT + DOCK_HEIGHT + 44)),
		Position = UDim2.new(1, -16, 0, TOP_HEIGHT + 28),
		AnchorPoint = Vector2.new(1, 0),
		ScrollBarThickness = 4,
		ZIndex = 18,
		[Children] = Kit.children(
			Kit.list(scope, { Padding = UDim.new(0, 10) }),
			tutorialCard,
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
			boardArea,
			zoomReset,
			topBar,
			dock,
			buildBar,
			wavePreview,
			bossPanel,
			connectionBanner,
			sideColumn
		),
	})
end
