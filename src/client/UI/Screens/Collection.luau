--!strict
-- Coleção e equipe. Cada torre é um cartão com retrato, papel e custo; o lado direito mostra as
-- quatro vagas da equipe. A equipe só vale depois de salvar (SetLoadout) — o servidor responde
-- com o perfil novo, que vira a fonte da verdade.
--
-- Durante uma partida a equipe fica congelada: o cartão explica em vez de simplesmente travar.
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
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children
local peek = Fusion.peek

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

local SLOTS = Balance.loadoutSlots

local function towerPortrait(towerId: string): string
	local entry = Assets.get(Assets.towerKey(towerId, "L0"))
	if not entry then
		return ""
	end
	return entry.portrait or entry.image or ""
end

local function masteryOf(profile: { [string]: any }?, towerId: string): number
	if not profile or not profile.masteryByTower then
		return 0
	end
	local entry = profile.masteryByTower[towerId]
	if typeof(entry) == "table" then
		return entry.points or 0
	end
	return entry or 0
end

return function(scope: Kit.Scope, props: Props): Frame
	local profile = Bridge.use(scope, Atoms.profile)
	local inMatch = Bridge.use(scope, Atoms.inMatch)
	local draft: Fusion.Value<{ string }> = scope:Value(Selectors.loadout())

	-- Perfil novo (ou tela reaberta) recomeça o rascunho a partir do que está salvo.
	Bridge.watch(scope, Atoms.profile, function()
		draft:set(Selectors.loadout())
	end)

	local dirty = scope:Computed(function(use)
		local current = use(draft)
		local saved = Selectors.loadout()
		if #current ~= #saved then
			return true
		end
		for index, id in ipairs(current) do
			if saved[index] ~= id then
				return true
			end
		end
		return false
	end)

	local function toggle(def: Types.TowerDef)
		if peek(inMatch) then
			Actions.toast(L("collection.readOnly"), "info")
			return
		end
		if not Selectors.owns(def.id) then
			local cost = def.unlock
			local balance = Selectors.buttons()
			if balance < cost then
				Actions.toast(L("collection.notEnough", { missing = cost - balance }), "error")
				return
			end
			Actions.openModal({
				title = L("unlock.title"),
				body = L("unlock.body", { tower = def.name, cost = cost }) .. "\n" .. L(
					"unlock.balance",
					{ balance = balance }
				) .. "\n" .. L("unlock.projected", { balance = balance - cost }),
				confirmText = L("unlock.confirm"),
				onConfirm = function()
					Actions.setModalPending(true)
					Commands.send("collection:buy:" .. def.id, "BuyTower", { towerId = def.id }, {
						onSuccess = function()
							Actions.closeModal()
							Actions.toast(L("collection.owned"), "success")
						end,
						onError = function(code)
							Actions.closeModal()
							Actions.toast(L("error." .. code), "error")
						end,
					})
				end,
			})
			return
		end
		local list = table.clone(peek(draft))
		local index = table.find(list, def.id)
		if index then
			table.remove(list, index)
		elseif #list >= SLOTS then
			Actions.toast(L("collection.teamFull"), "error")
			return
		else
			table.insert(list, def.id)
		end
		draft:set(list)
	end

	local cards: { any } = {
		Kit.grid(scope, UDim2.fromOffset(200, 228), 14),
	}
	for index, def in ipairs(Balance.towers) do
		local owned = scope:Computed(function(use)
			local _ = use(profile)
			return Selectors.owns(def.id)
		end)
		local equipped = scope:Computed(function(use)
			return table.find(use(draft), def.id) ~= nil
		end)
		table.insert(
			cards,
			Kit.pressable(scope, {
				name = "Tower_" .. def.id,
				size = UDim2.fromOffset(200, 228),
				layoutOrder = index,
				zIndex = 3,
				onActivate = function()
					toggle(def)
				end,
				children = Kit.children(Kit.panel(scope, {
					name = "Card",
					size = UDim2.fromScale(1, 1),
					color = scope:Computed(function(use)
						if not use(owned) then
							return Theme.colors.sage
						end
						return if use(equipped) then Theme.colors.cream else Theme.colors.paper
					end),
					strokeColor = scope:Computed(function(use)
						return if use(equipped) then Theme.colors.gold else Theme.colors.ink
					end),
					padding = 12,
					zIndex = 3,
					layout = Kit.list(scope, { Padding = UDim.new(0, 6) }),
					children = Kit.children(
						scope:New("ImageLabel")({
							Name = "Portrait",
							BackgroundTransparency = 1,
							Image = towerPortrait(def.id),
							ImageTransparency = scope:Computed(function(use)
								return if use(owned) then 0 else 0.55
							end),
							ScaleType = Enum.ScaleType.Fit,
							Size = UDim2.new(1, 0, 0, 96),
							LayoutOrder = 1,
							ZIndex = 4,
						}),
						Kit.title(scope, {
							Text = def.name,
							TextSize = 20,
							Size = UDim2.new(1, 0, 0, 24),
							LayoutOrder = 2,
							ZIndex = 4,
						}),
						Kit.caption(scope, {
							Text = def.role,
							Size = UDim2.new(1, 0, 0, 16),
							LayoutOrder = 3,
							ZIndex = 4,
						}),
						Kit.caption(scope, {
							Text = scope:Computed(function(use)
								local currentProfile = Kit.read(use, profile)
								if not Kit.read(use, owned) then
									return L("collection.unlockCost", { cost = def.unlock })
								end
								return L("collection.mastery", { points = masteryOf(currentProfile, def.id) })
							end),
							TextColor3 = scope:Computed(function(use)
								return if use(owned) then Theme.colors.muted else Theme.colors.goldText
							end),
							Size = UDim2.new(1, 0, 0, 16),
							LayoutOrder = 4,
							ZIndex = 4,
						}),
						Kit.tag(scope, {
							text = scope:Computed(function(use)
								if not Kit.read(use, owned) then
									return L("collection.locked")
								end
								return if Kit.read(use, equipped)
									then L("collection.equipped")
									else L("collection.equip")
							end),
							color = scope:Computed(function(use)
								if not Kit.read(use, owned) then
									return Theme.colors.sageDeep
								end
								return if Kit.read(use, equipped) then Theme.colors.gold else Theme.colors.cyan
							end),
							frame = { LayoutOrder = 5, ZIndex = 4 },
						})
					),
				})),
			})
		)
	end

	local slots: { any } = { Kit.list(scope, { Padding = UDim.new(0, 8) }) }
	for slot = 1, SLOTS do
		table.insert(
			slots,
			Kit.pressable(scope, {
				name = "Slot" .. slot,
				size = UDim2.new(1, 0, 0, 64),
				layoutOrder = slot,
				zIndex = 4,
				onActivate = function()
					local list = table.clone(peek(draft))
					if list[slot] then
						table.remove(list, slot)
						draft:set(list)
					end
				end,
				children = Kit.children(Kit.panel(scope, {
					name = "SlotCard",
					size = UDim2.fromScale(1, 1),
					color = scope:Computed(function(use)
						return if use(draft)[slot] then Theme.colors.cream else Theme.colors.sage
					end),
					padding = 12,
					paddingVertical = 8,
					zIndex = 4,
					shadow = false,
					layout = Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					children = Kit.children(
						scope:New("ImageLabel")({
							Name = "Portrait",
							BackgroundTransparency = 1,
							Image = scope:Computed(function(use)
								local towerId = use(draft)[slot]
								return if towerId then towerPortrait(towerId) else ""
							end),
							ScaleType = Enum.ScaleType.Fit,
							Size = UDim2.fromOffset(44, 44),
							LayoutOrder = 1,
							ZIndex = 5,
						}),
						Kit.text(scope, {
							Text = scope:Computed(function(use)
								local towerId = use(draft)[slot]
								if not towerId then
									return L("collection.freeSlot")
								end
								local def = Catalog.getTower(towerId)
								return if def then def.name else towerId
							end),
							Font = Theme.fonts.bodyBold,
							TextSize = 16,
							Size = UDim2.new(1, -60, 1, 0),
							LayoutOrder = 2,
							ZIndex = 5,
						})
					),
				})),
			})
		)
	end

	local screen = Kit.screen(scope, {
		name = "CollectionScreen",
		title = L("collection.title"),
		subtitle = L("collection.subtitle"),
		visible = props.visible,
		onBack = function()
			if not Actions.back() then
				Actions.navigate("menu")
			end
		end,
		header = Kit.children(Kit.chip(scope, {
			name = "Buttons",
			icon = "ui_buttons",
			caption = L("common.buttons"),
			value = scope:Computed(function(use)
				local _ = use(profile)
				return tostring(Selectors.buttons())
			end),
			accent = Theme.colors.gold,
			width = UDim2.new(0, 0, 0, 52),
		})),
		children = Kit.children(
			scope:New("Frame")({
				Name = "Cards",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -300, 1, 0),
				ZIndex = 3,
				[Children] = cards,
			}),
			Kit.panel(scope, {
				name = "Team",
				size = UDim2.new(0, 280, 1, -8),
				position = UDim2.new(1, 0, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				padding = 16,
				zIndex = 3,
				layout = Kit.list(scope, { Padding = UDim.new(0, 10) }),
				children = Kit.children(
					Kit.title(scope, {
						Text = L("menu.team"),
						TextSize = 22,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = 1,
						ZIndex = 4,
					}),
					Kit.caption(scope, {
						Text = scope:Computed(function(use)
							return L("collection.hint", { count = #use(draft), max = SLOTS })
						end),
						Size = UDim2.new(1, 0, 0, 16),
						LayoutOrder = 2,
						ZIndex = 4,
					}),
					scope:New("Frame")({
						Name = "Slots",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, SLOTS * 72),
						LayoutOrder = 3,
						ZIndex = 4,
						[Children] = slots,
					}),
					Kit.caption(scope, {
						Text = L("collection.readOnly"),
						Visible = inMatch,
						TextColor3 = Theme.colors.danger,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 4,
						ZIndex = 4,
					}),
					Kit.button(scope, {
						name = "Save",
						text = L("collection.save"),
						kind = "primary",
						size = UDim2.new(1, 0, 0, 52),
						layoutOrder = 5,
						zIndex = 4,
						disabled = scope:Computed(function(use)
							return not Kit.read(use, dirty) or Kit.read(use, inMatch)
						end),
						sub = scope:Computed(function(use)
							return if use(dirty) then "" else L("collection.noChanges")
						end),
						onActivate = function()
							Commands.send("profile:loadout", "SetLoadout", { towerIds = table.clone(peek(draft)) }, {
								onSuccess = function()
									Actions.toast(L("collection.saved"), "success")
								end,
								onError = function(code)
									Actions.toast(L("error." .. code), "error")
								end,
							})
						end,
					}),
					Kit.button(scope, {
						name = "Cosmetics",
						text = L("cosmetics.title"),
						kind = "secondary",
						size = UDim2.new(1, 0, 0, 48),
						layoutOrder = 6,
						zIndex = 4,
						onActivate = function()
							local first = peek(draft)[1] or Balance.towers[1].id
							Actions.push("cosmetics", { towerId = first })
						end,
					})
				),
			})
		),
	})
	return screen.instance
end
