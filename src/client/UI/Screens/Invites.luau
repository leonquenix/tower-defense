--!strict
-- 33_convites e os cartões de convite da prancha 40.
--
-- Contrato:
--  * só pessoas elegíveis aparecem (presentes, fora de grupo e fora de partida);
--  * estados por destinatário: convidar, enviado, aceito, recusado, expirado, grupo cheio, em partida;
--  * cooldown de 5 s por destinatário, sem repetição automática;
--  * o convite expira em 30 s de relógio real: expirado some e nunca é aceito só porque o botão ficou;
--  * o servidor valida remetente, vaga, sessão e token; a UI não decide entrada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local Store = require(script.Parent.Parent.Store)

local Invites = {}
Invites.__index = Invites

local L = Localization.get

export type Callbacks = { onBack: () -> () }

export type Invites = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		list: ScrollingFrame,
		buttons: { Components.Button },
	},
	Invites
))

function Invites.new(parent: Instance, callbacks: Callbacks): Invites
	local self = setmetatable({ callbacks = callbacks, buttons = {} }, Invites) :: any
	self.chrome = Chrome.new(parent, {
		name = "InvitesScreen",
		title = L("invites.title"),
		subtitle = L("invites.subtitle"),
		onBack = callbacks.onBack,
	})
	self.list = Components.scroller(self.chrome.body, "List", { ZIndex = 2 })
	local layout = Components.list(self.list, Enum.FillDirection.Vertical, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return self
end

function Invites.send(self: Invites, userId: number, button: Components.Button)
	if Store.inviteCooldownLeft(userId) > 0 then
		return
	end
	button:setPending(true)
	CommandAdapter.send("party:invite:" .. userId, "InviteToParty", { userId = userId }, {
		onSuccess = function()
			button:setPending(false)
			button:flashSuccess(L("invites.sent"))
			Store.markInviteSent(userId, "sent")
			task.delay(5.2, function()
				if self.chrome.root.Visible then
					Invites.render(self)
				end
			end)
		end,
		onError = function(code)
			button:setPending(false)
			button:showError(if code == "INVALID_STATE" then L("invites.unavailable") else L("common.retry"))
		end,
	})
end

function Invites.render(self: Invites)
	self.chrome:refreshBalance()
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	for _, child in ipairs(self.list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local party = Store.party()
	local hasSlot = party == nil or #party.members < Balance.partyMax
	local candidates = 0

	for index, other in ipairs(Store.players()) do
		if other.userId ~= Players.LocalPlayer.UserId then
			candidates += 1
			local card = Components.panel(self.list, "P" .. other.userId, {
				Size = UDim2.new(1, 0, 0, 76),
				LayoutOrder = index,
				ZIndex = 3,
			}, { shadow = false })
			Components.padding(card, 16, 12)
			Components.label(card, "Name", other.name, {
				Size = UDim2.new(1, -260, 0, 26),
				Font = Theme.fonts.bodyBold,
				TextSize = Theme.sizes.bodyLarge,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 4,
			})
			local situation = if other.inMatch
				then L("invites.inMatch")
				elseif other.inParty then L("invites.inParty")
				else L("invites.available")
			Components.caption(card, "Situation", situation, {
				Size = UDim2.new(1, -260, 0, 20),
				Position = UDim2.fromOffset(0, 28),
				ZIndex = 4,
			})

			local sent = Store.get().sentInvites[other.userId]
			local cooldown = Store.inviteCooldownLeft(other.userId)
			local button: Components.Button
			button = Components.button(card, {
				name = "Invite",
				text = L("menu.invite"),
				kind = "primary",
				size = UDim2.fromOffset(239, Theme.sizes.buttonTarget),
				position = UDim2.new(1, -239, 0.5, -24),
				zIndex = 4,
				onActivate = function()
					Invites.send(self, other.userId, button)
				end,
			})
			if other.inMatch then
				button:setAvailable(false, L("invites.inMatch"))
			elseif other.inParty then
				button:setAvailable(false, L("invites.inParty"))
			elseif not hasSlot then
				button:setAvailable(false, L("invites.partyFull"))
			elseif cooldown > 0 then
				button:setText(L("invites.sent"))
				button:setAvailable(false, L("invites.cooldown", { seconds = math.ceil(cooldown) }))
			elseif sent then
				button:setText(L("menu.invite"))
			end
			table.insert(self.buttons, button)
		end
	end

	if candidates == 0 then
		Components.emptyState(self.list, "Empty", L("invites.nobody"), {
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 1,
		})
	end
end

function Invites.show(self: Invites)
	self.chrome:show()
	Invites.render(self)
end

function Invites.hide(self: Invites)
	self.chrome:hide()
end

return Invites
