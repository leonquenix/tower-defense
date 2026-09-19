--!strict
-- Cartões de convite recebidos (prancha 33). Entram pela camada de avisos: não bloqueiam o
-- combate, não roubam foco e mostram o prazo real do token emitido pelo servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.Parent.State.Bridge)
local Commands = require(script.Parent.Parent.Parent.Net.Commands)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Kit = require(script.Parent.Parent.Kit)

local Children = Fusion.Children

local L = Localization.get

local function respond(invite: Atoms.Invite, accept: boolean)
	Actions.setInviteState(invite.inviteId, if accept then "accepted" else "declined")
	Commands.send(
		"party:invite:respond:" .. invite.inviteId,
		"RespondInvite",
		{ inviteId = invite.inviteId, accept = accept },
		{
			onSuccess = function()
				Actions.removeInvite(invite.inviteId)
				if accept then
					Actions.navigate("party")
				end
			end,
			onError = function(code)
				Actions.removeInvite(invite.inviteId)
				Actions.toast(L("error." .. code), "error")
			end,
		}
	)
end

return function(scope: Kit.Scope): Frame
	local invites = Bridge.use(scope, Atoms.invites)

	return scope:New("Frame")({
		Name = "InviteCards",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 340, 1, -160),
		Position = UDim2.new(1, -24, 0, 120),
		AnchorPoint = Vector2.new(1, 0),
		Active = false,
		ZIndex = 55,
		[Children] = Kit.children(
			Kit.list(scope, {
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			}),
			scope:ForValues(invites, function(_, innerScope: Kit.Scope, invite: Atoms.Invite)
				local map = if invite.mapId then Catalog.getMap(invite.mapId) else nil
				local pending = invite.state == "pending"
				return Kit.panel(innerScope, {
					name = "Invite_" .. invite.inviteId,
					size = UDim2.new(0, 320, 0, 0),
					automaticSize = Enum.AutomaticSize.Y,
					color = if pending then Theme.colors.paper else Theme.colors.sage,
					padding = 14,
					zIndex = 56,
					layout = Kit.list(innerScope, { Padding = UDim.new(0, 8) }),
					children = Kit.children(
						Kit.title(innerScope, {
							Text = L("invites.from", { name = invite.fromName }),
							TextSize = 18,
							Size = UDim2.new(1, 0, 0, 22),
							LayoutOrder = 1,
							ZIndex = 57,
						}),
						Kit.caption(innerScope, {
							Text = if map
								then L("invites.detail", {
									map = map.name,
									difficulty = L("menu.difficulty." .. tostring(invite.difficulty)),
								})
								else L("invites.detailUnknown"),
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							LayoutOrder = 2,
							ZIndex = 57,
						}),
						-- convite vencido explica em vez de sumir na cara de quem ia aceitar
						Kit.caption(innerScope, {
							Text = L("invites.expired"),
							Visible = invite.state == "expired",
							TextColor3 = Theme.colors.danger,
							Size = UDim2.new(1, 0, 0, 16),
							LayoutOrder = 3,
							ZIndex = 57,
						}),
						innerScope:New("Frame")({
							Name = "Actions",
							BackgroundTransparency = 1,
							Visible = pending,
							Size = UDim2.new(1, 0, 0, 44),
							LayoutOrder = 4,
							ZIndex = 57,
							[Children] = Kit.children(
								Kit.list(innerScope, {
									FillDirection = Enum.FillDirection.Horizontal,
									Padding = UDim.new(0, 8),
									VerticalAlignment = Enum.VerticalAlignment.Center,
								}),
								Kit.button(innerScope, {
									name = "Decline",
									text = L("invites.decline"),
									kind = "secondary",
									size = UDim2.fromOffset(140, 42),
									layoutOrder = 1,
									zIndex = 58,
									onActivate = function()
										respond(invite, false)
									end,
								}),
								Kit.button(innerScope, {
									name = "Accept",
									text = L("invites.accept"),
									kind = "primary",
									size = UDim2.fromOffset(150, 42),
									layoutOrder = 2,
									zIndex = 58,
									onActivate = function()
										respond(invite, true)
									end,
								})
							),
						})
					),
				})
			end)
		),
	})
end
