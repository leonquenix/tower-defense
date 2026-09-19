--!strict
-- Campanha: a lista de fases. Cada cartão traz a arte do mapa com a etiqueta do cenário, o nome
-- da fase, as três estrelas e o bloco de objetivos — os dois que valem a segunda e a terceira.
--
-- A fase seguinte abre com pelo menos uma estrela na anterior. A regra mora no perfil
-- (ProfileSchema.isLevelUnlocked) e o servidor confere de novo ao começar a partida; aqui é só
-- leitura, para a tela não prometer o que o servidor recusaria.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local DevFlags = require(ReplicatedStorage.Shared.Config.DevFlags)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Types = require(ReplicatedStorage.Shared.Types)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local CARD_WIDTH = 392
local CARD_HEIGHT = 288
local ART_HEIGHT = 124

-- Etiqueta do cenário: um glifo por mapa, para bater o olho e saber onde a fase acontece.
local MAP_GLYPH: { [string]: string } = { jardim = "🍃", oficina = "❄", sotao = "🌙" }

-- Texto do objetivo em linguagem do jogador. Objetivo novo num cliente velho vira linha vazia,
-- nunca erro.
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

local function starsOf(profile: { [string]: any }?, levelId: string): number
	if not profile or typeof(profile.campaign) ~= "table" then
		return 0
	end
	local stars = profile.campaign[levelId]
	return if typeof(stars) == "number" then stars else 0
end

-- Uma estrela: dourada com contorno quando conquistada, apagada quando não.
local function star(scope: Kit.Scope, filled: Kit.Used<number>, index: number, size: number): TextLabel
	local earned = scope:Computed(function(use)
		return Kit.read(use, filled) >= index
	end)
	local label = Kit.text(scope, {
		Name = "Star" .. index,
		Text = "★",
		Font = Theme.fonts.title,
		TextSize = size,
		TextColor3 = scope:Computed(function(use)
			return if use(earned) then Theme.colors.gold else Theme.colors.sageDeep
		end),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(size + 6, size + 6),
		LayoutOrder = index,
		ZIndex = 6,
	})
	local stroke = scope:New("UIStroke")({
		Color = scope:Computed(function(use)
			return if use(earned) then Theme.colors.goldDark else Theme.colors.sage
		end),
		Thickness = 2,
	})
	stroke.Parent = label
	return label
end

local function starRow(scope: Kit.Scope, filled: Kit.Used<number>, size: number, order: number): Frame
	return scope:New("Frame")({
		Name = "Stars",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size + 8),
		LayoutOrder = order,
		ZIndex = 6,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			star(scope, filled, 1, size),
			star(scope, filled, 2, size),
			star(scope, filled, 3, size)
		),
	})
end

-- Uma linha de objetivo: estrelinha + texto, dentro do bloco claro do cartão.
local function objectiveLine(
	scope: Kit.Scope,
	objective: Types.ObjectiveDef,
	stars: Kit.Used<number>,
	position: number
): Frame
	local done = scope:Computed(function(use)
		-- a estrela 1 é vencer; a posição 1 dos objetivos vale a estrela 2
		return Kit.read(use, stars) >= position + 1
	end)
	return scope:New("Frame")({
		Name = "Objective" .. position,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = position,
		ZIndex = 6,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Kit.text(scope, {
				Name = "Mark",
				Text = "★",
				Font = Theme.fonts.title,
				TextSize = 16,
				TextColor3 = scope:Computed(function(use)
					return if use(done) then Theme.colors.gold else Theme.colors.sageDeep
				end),
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(18, 18),
				LayoutOrder = 1,
				ZIndex = 7,
			}),
			Kit.text(scope, {
				Name = "Text",
				Text = objectiveText(objective),
				TextSize = 14,
				Font = Theme.fonts.bodyMedium,
				TextColor3 = scope:Computed(function(use)
					return if use(done) then Theme.colors.ink else Theme.colors.muted
				end),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, -26, 1, 0),
				LayoutOrder = 2,
				ZIndex = 7,
			})
		),
	})
end

return function(scope: Kit.Scope, props: Props): Frame
	local profile_ = Bridge.use(scope, Atoms.profile)
	local levels = Catalog.levels()

	-- Total de estrelas: é o que dá a sensação de coleção.
	local totalStars = scope:Computed(function(use)
		local profile = Kit.read(use, profile_)
		local sum = 0
		for _, level in ipairs(levels) do
			sum += starsOf(profile, level.id)
		end
		return sum
	end)

	local cards: { any } = {}
	for index, level in ipairs(levels) do
		local map = Catalog.getMap(level.mapId)
		local stars = scope:Computed(function(use)
			return starsOf(Kit.read(use, profile_), level.id)
		end)
		local unlocked = scope:Computed(function(use)
			if DevFlags.unlockAllMaps then
				return true
			end
			local previous = levels[index - 1]
			if not previous then
				return true -- a primeira fase é sempre aberta
			end
			return starsOf(Kit.read(use, profile_), previous.id) >= 1
		end)
		-- cartão em destaque: a próxima fase a jogar (aberta, ainda sem as três estrelas, e com
		-- todas as anteriores completas)
		local current = scope:Computed(function(use)
			if not Kit.read(use, unlocked) or Kit.read(use, stars) >= 3 then
				return false
			end
			for other = 1, index - 1 do
				if starsOf(Kit.read(use, profile_), levels[other].id) < 3 then
					return false
				end
			end
			return true
		end)

		local objectiveLines: { any } = { Kit.list(scope, { Padding = UDim.new(0, 4) }) }
		for position, objective in ipairs(level.objectives) do
			table.insert(objectiveLines, objectiveLine(scope, objective, stars, position))
		end

		table.insert(
			cards,
			Kit.pressable(scope, {
				name = "Level_" .. level.id,
				size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
				layoutOrder = index,
				zIndex = 4,
				onActivate = function()
					if Fusion.peek(unlocked) then
						GameFlow.startLevel(level.id)
					else
						Actions.toast(L("campaign.locked"), "error")
					end
				end,
				children = Kit.children(Kit.panel(scope, {
					name = "Card",
					size = UDim2.fromScale(1, 1),
					color = scope:Computed(function(use)
						return if Kit.read(use, unlocked) then Theme.colors.paper else Theme.colors.sage
					end),
					strokeColor = scope:Computed(function(use)
						if Kit.read(use, stars) >= 3 or Kit.read(use, current) then
							return Theme.colors.gold
						end
						return Theme.colors.ink
					end),
					radius = 20,
					padding = 14,
					paddingVertical = 14,
					zIndex = 4,
					layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
					children = Kit.children(
						-- arte do mapa com a etiqueta do cenário no canto
						scope:New("ImageLabel")({
							Name = "MapArt",
							BackgroundColor3 = Theme.colors.sage,
							BorderSizePixel = 0,
							Image = Assets.image(Assets.groundKey(level.mapId)) or "",
							ImageTransparency = scope:Computed(function(use)
								return if Kit.read(use, unlocked) then 0 else 0.7
							end),
							ScaleType = Enum.ScaleType.Crop,
							Size = UDim2.new(1, 0, 0, ART_HEIGHT),
							LayoutOrder = 1,
							ZIndex = 5,
							[Children] = Kit.children(
								Kit.corner(scope, 14),
								Kit.stroke(scope, Theme.colors.ink, 2),
								Kit.panel(scope, {
									name = "MapTag",
									size = UDim2.new(0, 0, 0, 28),
									automaticSize = Enum.AutomaticSize.X,
									position = UDim2.new(1, -8, 0, 8),
									anchorPoint = Vector2.new(1, 0),
									color = Theme.colors.ink,
									strokeColor = Theme.colors.inkDeep,
									radius = Kit.radius.pill,
									padding = 10,
									paddingVertical = 4,
									gloss = false,
									zIndex = 6,
									children = Kit.children(Kit.text(scope, {
										Text = (MAP_GLYPH[level.mapId] or "●") .. "  " .. (if map
											then map.name
											else level.mapId),
										TextColor3 = Theme.colors.cream,
										Font = Theme.fonts.bodyBold,
										TextSize = 13,
										TextWrapped = false,
										AutomaticSize = Enum.AutomaticSize.X,
										Size = UDim2.new(0, 0, 1, 0),
										ZIndex = 7,
									})),
								})
							),
						}),
						Kit.text(scope, {
							Name = "Title",
							Text = L(
								"campaign.levelName",
								{ index = index, map = if map then map.name else level.mapId }
							),
							Font = Theme.fonts.bodyBold,
							TextSize = 20,
							TextWrapped = false,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Size = UDim2.new(1, 0, 0, 24),
							LayoutOrder = 2,
							ZIndex = 6,
						}),
						starRow(scope, stars, 26, 3),
						-- bloco dos objetivos: fundo claro para separar do resto do cartão
						Kit.panel(scope, {
							name = "Objectives",
							size = UDim2.new(1, 0, 0, 60),
							color = Theme.colors.cream,
							strokeColor = Theme.colors.creamDark,
							radius = 12,
							padding = 10,
							paddingVertical = 6,
							gloss = false,
							shadow = false,
							layoutOrder = 4,
							zIndex = 5,
							layout = Kit.list(scope, { Padding = UDim.new(0, 4) }),
							children = objectiveLines,
						})
					),
					overlay = Kit.children(Kit.text(scope, {
						Name = "Lock",
						Text = "🔒",
						TextSize = 40,
						Visible = scope:Computed(function(use)
							return not Kit.read(use, unlocked)
						end),
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 9,
					})),
				})),
			})
		)
	end

	-- Painel de coleção no cabeçalho: quantas estrelas e para que elas servem.
	local collection = Kit.panel(scope, {
		name = "Collection",
		size = UDim2.fromOffset(470, 64),
		color = Theme.colors.paper,
		strokeColor = Theme.colors.goldDark,
		radius = 18,
		padding = 14,
		paddingVertical = 8,
		zIndex = 4,
		layout = Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		children = Kit.children(
			Kit.text(scope, {
				Name = "Icon",
				Text = "★",
				Font = Theme.fonts.title,
				TextSize = 34,
				TextColor3 = Theme.colors.gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(38, 38),
				LayoutOrder = 1,
				ZIndex = 5,
			}),
			scope:New("Frame")({
				Name = "Count",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(126, 44),
				LayoutOrder = 2,
				ZIndex = 5,
				[Children] = Kit.children(
					Kit.list(scope, { Padding = UDim.new(0, 0) }),
					Kit.text(scope, {
						Name = "Value",
						Text = scope:Computed(function(use)
							return tostring(Kit.read(use, totalStars)) .. "/" .. tostring(#levels * 3)
						end),
						Font = Theme.fonts.numbers,
						TextSize = 24,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = 1,
						ZIndex = 6,
					}),
					Kit.caption(scope, {
						Name = "Label",
						Text = L("campaign.starsCollected"),
						TextSize = 11,
						TextWrapped = false,
						Size = UDim2.new(1, 0, 0, 14),
						LayoutOrder = 2,
						ZIndex = 6,
					})
				),
			}),
			Kit.text(scope, {
				Name = "Hint",
				Text = L("campaign.starsHint"),
				TextSize = 13,
				Font = Theme.fonts.bodyMedium,
				TextColor3 = Theme.colors.muted,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, -194, 1, 0),
				LayoutOrder = 3,
				ZIndex = 5,
			})
		),
	})

	-- A grade fica direto no corpo rolável: com um quadro intermediário de altura automática o
	-- ScrollingFrame não enxergava o conteúdo e a lista não rolava.
	local screen = Kit.screen(scope, {
		name = "CampaignScreen",
		title = L("campaign.title"),
		subtitle = L("campaign.subtitle"),
		visible = props.visible,
		scroll = true,
		onBack = function()
			Actions.navigate("menu")
		end,
		header = Kit.children(collection),
		bodyLayout = Kit.grid(scope, UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT), 16),
		children = cards,
	})
	return screen.instance
end
