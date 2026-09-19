--!strict
-- Salas abertas neste servidor. Entrar em uma, criar a sua ou seguir sozinho.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Selectors = require(script.Parent.Parent.Parent.State.Selectors)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

type Room = { id: string, leaderName: string, size: number, mapId: string, difficulty: string }

return function(scope: Kit.Scope, props: Props): Frame
	local lobby = Bridge.use(scope, Atoms.lobby)
	local rooms = scope:Computed(function(use): { Room }
		local _ = use(lobby)
		return Selectors.rooms() :: { Room }
	end)
	local empty = scope:Computed(function(use)
		return #use(rooms) == 0
	end)

	local function join(roomId: string)
		Commands.send("party:join", "JoinParty", { partyId = roomId }, {
			onSuccess = function()
				Actions.navigate("party")
			end,
			onError = function(code)
				Actions.toast(L("error." .. code), "error")
			end,
		})
	end

	local screen = Kit.screen(scope, {
		name = "RoomsScreen",
		title = L("rooms.title"),
		subtitle = L("rooms.subtitle"),
		visible = props.visible,
		onBack = function()
			Actions.navigate("maps")
		end,
		header = Kit.children(Kit.button(scope, {
			name = "Create",
			text = L("menu.createParty"),
			kind = "primary",
			icon = "ui_group",
			size = UDim2.fromOffset(230, 52),
			onActivate = function()
				Commands.send("party:create", "CreateParty", {}, {
					onSuccess = function()
						Actions.navigate("party")
					end,
					onError = function(code)
						Actions.toast(L("error." .. code), "error")
					end,
				})
			end,
		})),
		children = Kit.children(
			Kit.caption(scope, {
				Name = "Empty",
				Text = L("menu.noRooms"),
				Visible = empty,
				Size = UDim2.new(1, 0, 0, 40),
				ZIndex = 3,
			}),
			scope:New("Frame")({
				Name = "List",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -80),
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, { Padding = UDim.new(0, 10) }),
					scope:ForValues(rooms, function(_, innerScope: Kit.Scope, room: Room)
						local map = Catalog.getMap(room.mapId)
						return Kit.panel(innerScope, {
							name = "Room_" .. room.id,
							size = UDim2.new(1, -8, 0, 84),
							padding = 16,
							paddingVertical = 12,
							zIndex = 3,
							layout = Kit.list(innerScope, {
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
										Kit.list(innerScope, { Padding = UDim.new(0, 2) }),
										Kit.title(innerScope, {
											Text = L("menu.partyOf", { leader = room.leaderName }),
											TextSize = 20,
											Size = UDim2.new(1, 0, 0, 24),
											LayoutOrder = 1,
											ZIndex = 4,
										}),
										Kit.caption(innerScope, {
											Text = (if map then map.name else room.mapId) .. " · " .. L(
												"menu.difficulty." .. room.difficulty
											) .. " · " .. tostring(room.size) .. "/4",
											Size = UDim2.new(1, 0, 0, 18),
											LayoutOrder = 2,
											ZIndex = 4,
										})
									),
								}),
								Kit.button(innerScope, {
									name = "Join",
									text = L("rooms.join"),
									kind = "cyan",
									size = UDim2.fromOffset(170, 48),
									layoutOrder = 2,
									zIndex = 4,
									disabled = room.size >= 4,
									sub = if room.size >= 4 then L("rooms.full") else "",
									onActivate = function()
										join(room.id)
									end,
								})
							),
						})
					end)
				),
			}),
			Kit.button(scope, {
				name = "Solo",
				text = L("maps.solo"),
				kind = "secondary",
				size = UDim2.fromOffset(240, 56),
				position = UDim2.new(1, 0, 1, -8),
				anchorPoint = Vector2.new(1, 1),
				zIndex = 4,
				onActivate = function()
					Actions.navigate("maps")
				end,
			})
		),
	})
	return screen.instance
end
