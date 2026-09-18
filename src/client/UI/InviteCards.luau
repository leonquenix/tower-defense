--!strict
-- Cartões de convite recebido (pranchas 33 e 40).
--
-- Contrato:
--  * cartão discreto: não rouba foco e não interrompe o combate;
--  * Aceitar e Recusar têm alvo de 48 px (Recusar é TextButton de verdade, não texto solto);
--  * o convite expira em 30 s de relógio real e some; expirado nunca é aceito;
--  * fechar o cartão não altera a partida atual;
--  * Aceitar tenta ingresso atômico: dois aceites para a última vaga resultam em uma entrada.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Config.Catalog)
local Theme = require(script.Parent.Parent.View.Theme)
local Components = require(script.Parent.Components)
local CommandAdapter = require(script.Parent.CommandAdapter)
local Store = require(script.Parent.Store)

local InviteCards = {}

local L = Localization.get

type Card = { frame: Frame, accept: Components.Button, decline: Components.Button, timer: TextLabel }

local host: Frame? = nil
local cards: { [string]: Card } = {}
local onAccepted: (() -> ())? = nil

local function destroyCard(inviteId: string)
	local card = cards[inviteId]
	if not card then
		return
	end
	cards[inviteId] = nil
	card.accept:destroy()
	card.decline:destroy()
	card.frame:Destroy()
	InviteCards.layout()
end

function InviteCards.layout()
	local index = 0
	for _, card in pairs(cards) do
		card.frame.Position = UDim2.new(1, -16, 1, -(16 + index * 128))
		index += 1
	end
end

local function respond(invite: Store.Invite, accept: boolean, card: Card)
	if os.clock() >= invite.expiresAt then
		Store.setInviteState(invite.inviteId, "expired")
		return
	end
	local button = if accept then card.accept else card.decline
	button:setPending(true)
	CommandAdapter.send(
		"party:respondInvite:" .. invite.inviteId,
		"RespondInvite",
		{ inviteId = invite.inviteId, accept = accept },
		{
			onSuccess = function()
				button:setPending(false)
				Store.removeInvite(invite.inviteId)
				destroyCard(invite.inviteId)
				if accept and onAccepted then
					onAccepted()
				end
			end,
			onError = function(code)
				button:setPending(false)
				-- a vaga pode ter sumido: o cartão explica e some, sem mexer na partida atual
				button:showError(if code == "INVALID_STATE" then L("invites.partyFull") else L("common.retry"))
				Store.setInviteState(invite.inviteId, if code == "INVALID_STATE" then "full" else "pending")
				task.delay(2.5, function()
					destroyCard(invite.inviteId)
				end)
			end,
		}
	)
end

local function buildCard(invite: Store.Invite): Card
	local parent = host :: Frame
	local frame = Components.panel(parent, "Invite_" .. invite.inviteId, {
		Size = UDim2.fromOffset(330, 118),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 8,
	}, { tape = true, shadow = false })
	Components.padding(frame, 14, 12)
	Components.label(frame, "From", L("invites.from", { name = invite.fromName }), {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.fonts.bodyBold,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 9,
	})
	local map = if invite.mapId then Catalog.getMap(invite.mapId) else nil
	Components.caption(
		frame,
		"Detail",
		if map
			then L("invites.detail", {
				map = map.name,
				difficulty = L("menu.difficulty." .. tostring(invite.difficulty or "normal")),
			})
			else L("invites.detailUnknown"),
		{
			Size = UDim2.new(1, -70, 0, 18),
			Position = UDim2.fromOffset(0, 24),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 9,
		}
	)
	local timer = Components.caption(frame, "Timer", "", {
		Size = UDim2.fromOffset(64, 18),
		Position = UDim2.new(1, -64, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 9,
	})
	local row = Components.frame(frame, "Row", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
		Position = UDim2.new(0, 0, 1, -Theme.sizes.buttonTarget),
		BackgroundTransparency = 1,
		ZIndex = 9,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 10)
	local card: Card
	local decline = Components.button(row, {
		name = "Decline",
		text = L("invites.decline"),
		kind = "secondary",
		size = UDim2.fromOffset(140, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		zIndex = 10,
		onActivate = function()
			respond(invite, false, card)
		end,
	})
	local accept = Components.button(row, {
		name = "Accept",
		text = L("invites.accept"),
		kind = "primary",
		size = UDim2.fromOffset(150, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 10,
		onActivate = function()
			respond(invite, true, card)
		end,
	})
	card = { frame = frame, accept = accept, decline = decline, timer = timer }
	return card
end

function InviteCards.init(parent: Frame, acceptedCallback: (() -> ())?)
	host = parent
	onAccepted = acceptedCallback
end

-- Chamado a cada segundo: cria cartões novos, atualiza a contagem e remove expirados.
function InviteCards.update(now: number)
	if not host then
		return
	end
	Store.expireInvites(now)
	local live: { [string]: boolean } = {}
	for _, invite in ipairs(Store.get().invites) do
		live[invite.inviteId] = true
		local card = cards[invite.inviteId]
		if invite.state == "pending" then
			if not card then
				card = buildCard(invite)
				cards[invite.inviteId] = card
				InviteCards.layout()
			end
			local left = math.max(0, math.ceil(invite.expiresAt - now))
			card.timer.Text = tostring(left) .. "s"
		elseif card then
			if invite.state == "expired" then
				card.accept:setAvailable(false, L("invites.expired"))
				card.decline:setText(L("common.close"))
				card.timer.Text = L("invites.expired")
			end
		end
	end
	for inviteId in pairs(cards) do
		if not live[inviteId] then
			destroyCard(inviteId)
		end
	end
end

function InviteCards.clear()
	for inviteId in pairs(cards) do
		destroyCard(inviteId)
	end
end

return InviteCards
