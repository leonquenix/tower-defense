--!strict
-- Carregamento da partida: mapa, dificuldade e as etapas que o cliente consegue afirmar.
-- Não inventa progresso do servidor; se demora, diz que demorou e deixa voltar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean>, elapsed: Fusion.UsedAs<number> }

local SLOW_AFTER = 8

return function(scope: Kit.Scope, props: Props): Frame
	local params = Bridge.use(scope, Atoms.routeParams)
	local mapName = scope:Computed(function(use)
		local map = Catalog.getMap(tostring(use(params).mapId or "jardim"))
		return if map then map.name else ""
	end)
	local mapImage = scope:Computed(function(use)
		return Assets.image(Assets.groundKey(tostring(use(params).mapId or "jardim"))) or ""
	end)
	local difficultyText = scope:Computed(function(use)
		return L("menu.difficulty." .. tostring(use(params).difficulty or "normal"))
	end)
	-- "{difficulty} · Equipe: {team}" precisa dos dois parâmetros: sem eles o cartão mostrava
	-- as chaves cruas na tela de carregamento.
	local loadout = Bridge.use(scope, Atoms.loadout)
	local setupText = scope:Computed(function(use)
		local names: { string } = {}
		local ids: { string } = Kit.read(use, loadout)
		for _, towerId in ipairs(ids) do
			local def = Catalog.getTower(towerId)
			table.insert(names, if def then def.name else towerId)
		end
		return L("loading.setup", {
			difficulty = Kit.read(use, difficultyText),
			team = if #names > 0 then table.concat(names, " · ") else L("menu.teamEmpty"),
		})
	end)
	local slow = scope:Computed(function(use)
		return Kit.read(use, props.elapsed) >= SLOW_AFTER
	end)

	return scope:New("Frame")({
		Name = "LoadingScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible,
		[Children] = Kit.children(Kit.panel(scope, {
			name = "Card",
			size = UDim2.new(0, 560, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			padding = 26,
			layout = Kit.list(scope, { Padding = UDim.new(0, 14) }),
			children = Kit.children(
				scope:New("ImageLabel")({
					Name = "Map",
					BackgroundColor3 = Theme.colors.sage,
					BorderSizePixel = 0,
					Image = mapImage,
					ScaleType = Enum.ScaleType.Crop,
					Size = UDim2.new(1, 0, 0, 150),
					LayoutOrder = 1,
					ZIndex = 3,
					[Children] = Kit.children(Kit.corner(scope, 14), Kit.stroke(scope, Theme.colors.ink, 2)),
				}),
				Kit.title(scope, {
					Text = mapName,
					TextSize = 28,
					Size = UDim2.new(1, 0, 0, 34),
					LayoutOrder = 2,
					ZIndex = 3,
				}),
				Kit.caption(scope, {
					Text = setupText,
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = 3,
					ZIndex = 3,
				}),
				Kit.bar(scope, {
					value = scope:Computed(function(use)
						local elapsed: number = Kit.read(use, props.elapsed)
						return math.min(elapsed / 4, 0.92)
					end),
					color = Theme.colors.gold,
					height = 10,
					layoutOrder = 4,
				}),
				Kit.caption(scope, {
					Text = L("loading.step.waitingServer"),
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = 5,
					ZIndex = 3,
				}),
				Kit.caption(scope, {
					Name = "Slow",
					Text = L("loading.slow"),
					Visible = slow,
					TextColor3 = Theme.colors.danger,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 6,
					ZIndex = 3,
				}),
				Kit.button(scope, {
					name = "Back",
					text = L("loading.back"),
					kind = "secondary",
					visible = slow,
					size = UDim2.fromOffset(200, 48),
					layoutOrder = 7,
					zIndex = 4,
					onActivate = function()
						Actions.navigate("menu")
					end,
				})
			),
		})),
	})
end
