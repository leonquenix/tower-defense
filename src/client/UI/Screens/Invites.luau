--!strict
-- Convidar quem está no servidor. Cada linha diz o estado real (em partida, já em grupo,
-- convidado) e respeita o intervalo de 5 s por destinatário.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

type Present = { userId: number, name: string, inMatch: boolean, inParty: boolean }

return function(scope: Kit.Scope, props: Props): Frame
	local lobby = Bridge.use(scope, Atoms.lobby)
	local sent = Bridge.use(scope, Atoms.sentInvites)
	local people = scope:Computed(function(use): { Present }
		local _ = use(lobby)
		local out: { Present } = {}
		for _, entry in ipairs(Selectors.players() :: { Present }) do
			if entry.userId ~= Players.LocalPlayer.UserId then
				table.insert(out, entry)
			end
		end
		return out
	end)
	local empty = scope:Computed(function(use)
		return #use(people) == 0
	end)

	local screen = Kit.screen(scope, {
		name = "InvitesScreen",
		title = L("invites.title"),
		subtitle = L("invites.subtitle"),
		visible = props.visible,
		onBack = function()
			if not Actions.back() then
				Actions.navigate("rooms")
			end
		end,
		children = Kit.children(
			Kit.caption(scope, {
				Name = "Empty",
				Text = L("invites.nobody"),
				Visible = empty,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 3,
			}),
			scope:New("Frame")({
				Name = "List",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
				[Children] = Kit.children(
					Kit.list(scope, { Padding = UDim.new(0, 8) }),
					scope:ForValues(people, function(_, innerScope: Kit.Scope, person: Present)
						local state = innerScope:Computed(function(use)
							local record = Kit.read(use, sent)[person.userId]
							if person.inMatch then
								return L("invites.inMatch")
							elseif person.inParty then
								return L("invites.inParty")
							elseif record then
								return L("invites.sent")
							end
							return L("invites.available")
						end)
						return Kit.panel(innerScope, {
							name = "Person_" .. tostring(person.userId),
							size = UDim2.new(1, -8, 0, 68),
							padding = 16,
							paddingVertical = 10,
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
									Size = UDim2.new(1, -190, 1, 0),
									LayoutOrder = 1,
									ZIndex = 4,
									[Children] = Kit.children(
										Kit.list(innerScope, { Padding = UDim.new(0, 2) }),
										Kit.title(innerScope, {
											Text = person.name,
											TextSize = 18,
											Size = UDim2.new(1, 0, 0, 22),
											LayoutOrder = 1,
											ZIndex = 4,
										}),
										Kit.caption(innerScope, {
											Text = state,
											Size = UDim2.new(1, 0, 0, 16),
											LayoutOrder = 2,
											ZIndex = 4,
										})
									),
								}),
								Kit.button(innerScope, {
									name = "Invite",
									text = L("menu.invite"),
									kind = "cyan",
									size = UDim2.fromOffset(160, 46),
									layoutOrder = 2,
									zIndex = 4,
									disabled = innerScope:Computed(function(use)
										local _ = Kit.read(use, sent)
										return person.inMatch
											or person.inParty
											or Selectors.inviteCooldownLeft(person.userId) > 0
									end),
									onActivate = function()
										Commands.send(
											"party:invite:" .. tostring(person.userId),
											"InviteToParty",
											{ userId = person.userId },
											{
												onSuccess = function()
													Actions.markInviteSent(person.userId, "sent")
													Actions.toast(L("invites.sent"), "success")
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
					end)
				),
			})
		),
	})
	return screen.instance
end
