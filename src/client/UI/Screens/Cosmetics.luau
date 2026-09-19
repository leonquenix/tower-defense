--!strict
-- Cosméticos por torre: o que já foi conquistado por domínio e o que ainda falta.
-- Nada aqui altera jogo; a tela diz isso com todas as letras.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local MILESTONES = { 30, 100, 250 }

return function(scope: Kit.Scope, props: Props): Frame
	local params = Bridge.use(scope, Atoms.routeParams)
	local profile = Bridge.use(scope, Atoms.profile)

	local towerId = scope:Computed(function(use)
		return tostring(use(params).towerId or "dardo")
	end)
	local towerName = scope:Computed(function(use)
		local def = Catalog.getTower(use(towerId))
		return if def then def.name else use(towerId)
	end)
	local points = scope:Computed(function(use)
		local current = Kit.read(use, profile)
		local id = Kit.read(use, towerId)
		if not current or not current.masteryByTower then
			return 0
		end
		local entry = current.masteryByTower[id]
		if typeof(entry) == "table" then
			return entry.points or 0
		end
		return entry or 0
	end)

	local items: { any } = { Kit.list(scope, { Padding = UDim.new(0, 10) }) }
	for index, milestone in ipairs(MILESTONES) do
		local unlocked = scope:Computed(function(use)
			return use(points) >= milestone
		end)
		local def = scope:Computed(function(use)
			return Products.masteryCosmetics(use(towerId))[milestone]
		end)
		table.insert(
			items,
			Kit.panel(scope, {
				name = "Milestone" .. tostring(milestone),
				size = UDim2.new(1, -8, 0, 84),
				padding = 16,
				paddingVertical = 12,
				color = scope:Computed(function(use)
					return if use(unlocked) then Theme.colors.cream else Theme.colors.sage
				end),
				layoutOrder = index,
				zIndex = 3,
				layout = Kit.list(scope, {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				children = Kit.children(
					scope:New("Frame")({
						Name = "Info",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -200, 1, 0),
						LayoutOrder = 1,
						ZIndex = 4,
						[Children] = Kit.children(
							Kit.list(scope, { Padding = UDim.new(0, 2) }),
							Kit.title(scope, {
								Text = L("cosmetics.milestone." .. tostring(milestone)),
								TextSize = 18,
								Size = UDim2.new(1, 0, 0, 22),
								LayoutOrder = 1,
								ZIndex = 4,
							}),
							Kit.caption(scope, {
								Text = scope:Computed(function(use)
									local cosmetic = use(def)
									return L("cosmetics.item." .. (if cosmetic then cosmetic.kind else "sticker"))
								end),
								Size = UDim2.new(1, 0, 0, 16),
								LayoutOrder = 2,
								ZIndex = 4,
							}),
							Kit.caption(scope, {
								Text = scope:Computed(function(use)
									if Kit.read(use, unlocked) then
										return L("cosmetics.unlockedAt", { points = milestone })
									end
									return L("cosmetics.requires", {
										points = milestone - Kit.read(use, points),
									})
								end),
								Size = UDim2.new(1, 0, 0, 16),
								LayoutOrder = 3,
								ZIndex = 4,
							})
						),
					}),
					Kit.button(scope, {
						name = "Equip",
						text = L("cosmetics.equip"),
						kind = "cyan",
						disabled = scope:Computed(function(use)
							return not use(unlocked)
						end),
						size = UDim2.fromOffset(170, 48),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = function()
							local cosmetic = Fusion.peek(def)
							if not cosmetic then
								return
							end
							Commands.send(
								"profile:cosmetic:" .. cosmetic.kind,
								"EquipCosmetic",
								{ slot = cosmetic.kind, cosmeticId = cosmetic.id },
								{
									onSuccess = function()
										Actions.toast(L("cosmetics.equipped"), "success")
									end,
									onError = function(code)
										Actions.toast(L("error." .. code), "error")
									end,
								}
							)
						end,
					})
				),
			})
		)
	end

	local screen = Kit.screen(scope, {
		name = "CosmeticsScreen",
		title = scope:Computed(function(use)
			return L("cosmetics.titleFor", { tower = use(towerName) })
		end),
		subtitle = L("cosmetics.subtitle"),
		visible = props.visible,
		onBack = function()
			if not Actions.back() then
				Actions.navigate("collection")
			end
		end,
		header = Kit.children(Kit.chip(scope, {
			name = "Mastery",
			icon = "ui_upgrade",
			caption = L("collection.mastery", { points = "" }),
			value = scope:Computed(function(use)
				return tostring(use(points))
			end),
			accent = Theme.colors.cyan,
			width = UDim2.new(0, 0, 0, 52),
		})),
		children = Kit.children(scope:New("Frame")({
			Name = "Items",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 3,
			[Children] = items,
		})),
	})
	return screen.instance
end
