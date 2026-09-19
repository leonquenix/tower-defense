--!strict
-- Escolha de mapa e dificuldade. Três cartões lado a lado (um por vez no celular), cadeado com
-- o motivo em linguagem do jogador e duas saídas: sozinho ou com amigos.
--
-- Em grupo, só o líder muda a seleção; a mudança vai para o servidor (PartySetup), que limpa a
-- prontidão de todo mundo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local GameFlow = require(script.Parent.Parent.Parent.Controllers.GameFlow)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children
local peek = Fusion.peek

local L = Localization.get

local MAP_ORDER = { "jardim", "oficina", "sotao" }

export type Props = { visible: Fusion.UsedAs<boolean> }

local function unlockKey(mapId: string, difficulty: string): string
	return mapId .. ":" .. difficulty
end

local function isUnlocked(profile: { [string]: any }?, mapId: string, difficulty: string): boolean
	if not profile then
		return false
	end
	local unlocks = profile.mapUnlocks
	if mapId == "jardim" and difficulty == "normal" then
		return profile.tutorialCompleted == true or (unlocks ~= nil and unlocks[unlockKey(mapId, difficulty)] == true)
	end
	return unlocks ~= nil and unlocks[unlockKey(mapId, difficulty)] == true
end

-- Texto do requisito de cada bloqueio, sempre em linguagem do jogador.
local function lockReason(mapId: string, difficulty: string): string
	if difficulty == "desafio" then
		return L("menu.lockedDesafio")
	end
	if mapId == "jardim" then
		return L("menu.lockedTutorial")
	end
	local previous = if mapId == "oficina" then "jardim" else "oficina"
	local map = Catalog.getMap(previous)
	return L("menu.lockedMap", { map = if map then map.name else previous })
end

return function(scope: Kit.Scope, props: Props): Frame
	local selectedMap: Fusion.Value<string> = scope:Value("jardim")
	local difficulty: Fusion.Value<string> = scope:Value("normal")
	local profile = Bridge.use(scope, Atoms.profile)
	local lobby = Bridge.use(scope, Atoms.lobby)

	local canConfigure = scope:Computed(function(use)
		local _ = use(lobby)
		local party = Selectors.party()
		if not party then
			return true
		end
		return party.leaderId == Players.LocalPlayer.UserId
	end)

	-- Seleção nova: em grupo o líder propaga para todo mundo.
	local function choose(mapId: string?, mode: string?)
		if not peek(canConfigure) then
			Actions.toast(L("menu.leaderOnly"), "info")
			return
		end
		if mapId then
			selectedMap:set(mapId)
		end
		if mode then
			difficulty:set(mode)
		end
		if Selectors.party() then
			Commands.send("party:setup", "PartySetup", { mapId = peek(selectedMap), mode = peek(difficulty) }, {
				onError = function(code)
					if code ~= "NOT_OWNER" then
						Actions.toast(L("error." .. code), "error")
					end
				end,
			})
		end
	end

	local cards: { any } = {
		Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 16),
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}
	for index, mapId in ipairs(MAP_ORDER) do
		local map = Catalog.getMap(mapId)
		if map then
			local unlocked = scope:Computed(function(use)
				-- Kit.read evita que Luau unifique os tipos de dois `use` na mesma closure
				return isUnlocked(Kit.read(use, profile), mapId, Kit.read(use, difficulty))
			end)
			local selected = scope:Computed(function(use)
				return use(selectedMap) == mapId
			end)
			table.insert(
				cards,
				Kit.pressable(scope, {
					name = "Map_" .. mapId,
					size = UDim2.new(0.33, -12, 1, 0),
					layoutOrder = index,
					zIndex = 3,
					onActivate = function()
						choose(mapId, nil)
					end,
					children = Kit.children(Kit.panel(scope, {
						name = "Card",
						size = UDim2.fromScale(1, 1),
						color = scope:Computed(function(use)
							return if use(selected) then Theme.colors.cream else Theme.colors.paper
						end),
						strokeColor = scope:Computed(function(use)
							return if use(selected) then Theme.colors.gold else Theme.colors.ink
						end),
						padding = 16,
						zIndex = 3,
						layout = Kit.list(scope, { Padding = UDim.new(0, 8) }),
						children = Kit.children(
							scope:New("ImageLabel")({
								Name = "Ground",
								BackgroundColor3 = Theme.colors.sage,
								BorderSizePixel = 0,
								Image = Assets.image(Assets.groundKey(mapId)) or "",
								ScaleType = Enum.ScaleType.Crop,
								Size = UDim2.new(1, 0, 0, 96),
								LayoutOrder = 1,
								ZIndex = 4,
								[Children] = Kit.children(
									Kit.corner(scope, 12),
									Kit.stroke(scope, Theme.colors.ink, 2)
								),
							}),
							Kit.title(scope, {
								Name = "Name",
								Text = map.name,
								TextSize = 22,
								Size = UDim2.new(1, 0, 0, 28),
								LayoutOrder = 2,
								ZIndex = 4,
							}),
							Kit.caption(scope, {
								Name = "Boss",
								Text = L("maps.boss", { name = L("enemy." .. map.boss) }),
								Size = UDim2.new(1, 0, 0, 18),
								LayoutOrder = 3,
								ZIndex = 4,
							}),
							Kit.panel(scope, {
								name = "Lock",
								visible = scope:Computed(function(use)
									return not use(unlocked)
								end),
								size = UDim2.new(1, 0, 0, 0),
								automaticSize = Enum.AutomaticSize.Y,
								color = Theme.colors.sage,
								strokeColor = Theme.colors.muted,
								radius = Kit.radius.chip,
								padding = 10,
								layoutOrder = 4,
								shadow = false,
								gloss = false,
								children = Kit.children(Kit.caption(scope, {
									Text = scope:Computed(function(use)
										return lockReason(mapId, use(difficulty))
									end),
									Size = UDim2.new(1, 0, 0, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									ZIndex = 5,
								})),
							})
						),
					})),
				})
			)
		end
	end

	local difficultyRow = scope:New("Frame")({
		Name = "Difficulty",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -140),
		ZIndex = 3,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Kit.caption(scope, {
				Text = L("menu.difficulty"),
				Size = UDim2.new(0, 110, 1, 0),
				LayoutOrder = 1,
				ZIndex = 4,
			}),
			Kit.button(scope, {
				name = "Normal",
				text = L("menu.difficulty.normal"),
				kind = "secondary",
				selected = scope:Computed(function(use)
					return use(difficulty) == "normal"
				end),
				size = UDim2.fromOffset(180, 48),
				layoutOrder = 2,
				zIndex = 4,
				onActivate = function()
					choose(nil, "normal")
				end,
			}),
			Kit.button(scope, {
				name = "Desafio",
				text = L("menu.difficulty.desafio"),
				kind = "secondary",
				selected = scope:Computed(function(use)
					return use(difficulty) == "desafio"
				end),
				size = UDim2.fromOffset(180, 48),
				layoutOrder = 3,
				zIndex = 4,
				onActivate = function()
					choose(nil, "desafio")
				end,
			})
		),
	})

	local actionsRow = scope:New("Frame")({
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.new(0, 0, 1, -72),
		ZIndex = 3,
		[Children] = Kit.children(
			Kit.list(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 12),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Kit.button(scope, {
				name = "Friends",
				text = L("maps.friends"),
				kind = "secondary",
				icon = "ui_group",
				size = UDim2.fromOffset(240, 60),
				layoutOrder = 1,
				zIndex = 4,
				onActivate = function()
					Actions.navigate("rooms")
				end,
			}),
			Kit.button(scope, {
				name = "Solo",
				text = L("maps.solo"),
				kind = "primary",
				icon = "ui_play",
				size = UDim2.fromOffset(280, 60),
				layoutOrder = 2,
				zIndex = 4,
				disabled = scope:Computed(function(use)
					return not isUnlocked(Kit.read(use, profile), Kit.read(use, selectedMap), Kit.read(use, difficulty))
				end),
				sub = scope:Computed(function(use)
					local mapId = Kit.read(use, selectedMap)
					local mode = Kit.read(use, difficulty)
					if not isUnlocked(Kit.read(use, profile), mapId, mode) then
						return lockReason(mapId, mode)
					end
					return ""
				end),
				onActivate = function()
					GameFlow.startMatch(peek(selectedMap), peek(difficulty), "normal")
				end,
			})
		),
	})

	local screen = Kit.screen(scope, {
		name = "MapsScreen",
		title = L("maps.title"),
		subtitle = L("maps.subtitle"),
		visible = props.visible,
		onBack = function()
			Actions.navigate("menu")
		end,
		children = Kit.children(
			scope:New("Frame")({
				Name = "Cards",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 280),
				ZIndex = 3,
				[Children] = cards,
			}),
			difficultyRow,
			actionsRow
		),
	})
	return screen.instance
end
