--!strict
-- Grupo: quem está dentro, quem já está pronto, mapa combinado e o botão de começar.
-- Só o líder começa; os outros veem "aguardando o líder". O servidor confirma tudo de novo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local L = Localization.get

export type Props = { visible: Fusion.UsedAs<boolean> }

type Member = { userId: number, name: string, ready: boolean, loadout: { string }, unlocked: boolean }

return function(scope: Kit.Scope, props: Props): Frame
	local lobby = Bridge.use(scope, Atoms.lobby)
	local party = scope:Computed(function(use)
		local _ = use(lobby)
		return Selectors.party()
	end)
	local members = scope:Computed(function(use): { Member }
		local current = use(party)
		return if current then (current.members or {}) else {}
	end)
	local isLeader = scope:Computed(function(use)
		local current = use(party)
		return current ~= nil and current.leaderId == Players.LocalPlayer.UserId
	end)
	local setupText = scope:Computed(function(use)
		local current = use(party)
		if not current then
			return L("party.none")
		end
		local map = Catalog.getMap(current.mapId)
		return L("party.setup")
			.. ": "
			.. (if map then map.name else tostring(current.mapId))
			.. " · "
			.. L("menu.difficulty." .. tostring(current.difficulty))
	end)
	local myReady = scope:Computed(function(use)
		for _, member in ipairs(use(members)) do
			if member.userId == Players.LocalPlayer.UserId then
				return member.ready
			end
		end
		return false
	end)

	local screen = Kit.screen(scope, {
		name = "PartyScreen",
		title = L("party.title"),
		subtitle = L("party.subtitle"),
		visible = props.visible,
		onBack = function()
			Actions.navigate("maps")
		end,
		header = Kit.children(Kit.button(scope, {
			name = "Leave",
			text = L("menu.leaveParty"),
			kind = "danger",
			size = UDim2.fromOffset(200, 52),
			onActivate = function()
				Commands.send("party:leave", "LeaveParty", {}, {
					onSuccess = function()
						Actions.navigate("maps")
					end,
				})
			end,
		})),
		children = Kit.children(
			Kit.caption(scope, {
				Name = "Setup",
				Text = setupText,
				Size = UDim2.new(1, 0, 0, 22),
				ZIndex = 3,
			}),
			scope:New("Frame")({
				Name = "Members",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 320),
				Position = UDim2.fromOffset(0, 32),
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, { Padding = UDim.new(0, 10) }),
					scope:ForValues(members, function(_, innerScope: Kit.Scope, member: Member)
						local names: { string } = {}
						for _, towerId in ipairs(member.loadout) do
							local def = Catalog.getTower(towerId)
							if def then
								table.insert(names, def.name)
							end
						end
						return Kit.panel(innerScope, {
							name = "Member_" .. tostring(member.userId),
							size = UDim2.new(1, -8, 0, 76),
							padding = 16,
							paddingVertical = 10,
							color = if member.ready then Theme.colors.cream else Theme.colors.paper,
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
									Size = UDim2.new(1, -180, 1, 0),
									LayoutOrder = 1,
									ZIndex = 4,
									[Children] = Kit.children(
										Kit.list(innerScope, { Padding = UDim.new(0, 2) }),
										Kit.title(innerScope, {
											Text = member.name,
											TextSize = 19,
											Size = UDim2.new(1, 0, 0, 22),
											LayoutOrder = 1,
											ZIndex = 4,
										}),
										Kit.caption(innerScope, {
											Text = if #names > 0
												then L("menu.teamReady", { team = table.concat(names, " · ") })
												else L("menu.teamEmpty"),
											Size = UDim2.new(1, 0, 0, 18),
											LayoutOrder = 2,
											ZIndex = 4,
										}),
										Kit.caption(innerScope, {
											Text = L("party.mapLocked"),
											Visible = not member.unlocked,
											TextColor3 = Theme.colors.danger,
											Size = UDim2.new(1, 0, 0, 16),
											LayoutOrder = 3,
											ZIndex = 4,
										})
									),
								}),
								Kit.tag(innerScope, {
									text = if member.ready then L("common.ready") else L("common.notReady"),
									color = if member.ready then Theme.colors.teal else Theme.colors.sage,
									frame = { LayoutOrder = 2, ZIndex = 4 },
								})
							),
						})
					end)
				),
			}),
			scope:New("Frame")({
				Name = "Actions",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 64),
				Position = UDim2.new(0, 0, 1, -72),
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Kit.button(scope, {
						name = "Invite",
						text = L("menu.invite"),
						kind = "secondary",
						icon = "ui_group",
						size = UDim2.fromOffset(200, 56),
						layoutOrder = 1,
						zIndex = 4,
						onActivate = function()
							Actions.push("invites")
						end,
					}),
					Kit.button(scope, {
						name = "Team",
						text = L("party.editTeam"),
						kind = "secondary",
						size = UDim2.fromOffset(200, 56),
						layoutOrder = 2,
						zIndex = 4,
						onActivate = function()
							Actions.push("collection")
						end,
					}),
					Kit.button(scope, {
						name = "Ready",
						text = scope:Computed(function(use)
							return if use(myReady) then L("party.cancelReady") else L("common.ready")
						end),
						kind = "cyan",
						visible = scope:Computed(function(use)
							return not use(isLeader)
						end),
						size = UDim2.fromOffset(200, 56),
						layoutOrder = 3,
						zIndex = 4,
						onActivate = function()
							Commands.send("party:ready", "PartyReady", { ready = not Fusion.peek(myReady) }, nil)
						end,
					}),
					Kit.button(scope, {
						name = "Start",
						text = L("menu.start"),
						sub = scope:Computed(function(use)
							return if use(isLeader) then "" else L("menu.waitingLeader")
						end),
						kind = "primary",
						icon = "ui_play",
						disabled = scope:Computed(function(use)
							return not use(isLeader)
						end),
						size = UDim2.fromOffset(240, 56),
						layoutOrder = 4,
						zIndex = 4,
						onActivate = function()
							local current = Fusion.peek(party)
							if current then
								GameFlow.startMatch(tostring(current.mapId), tostring(current.difficulty), "normal")
							end
						end,
					})
				),
			})
		),
	})
	return screen.instance
end
