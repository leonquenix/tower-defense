--!strict
-- 05_grupo (e os cartões de estado da prancha 40): revisar equipe e confirmar que todos podem começar.
--
-- Contrato:
--  * o líder escolhe mapa e dificuldade; cada pessoa muda a própria equipe e a própria prontidão;
--  * "Começar" é exclusivo do líder e exige todos os presentes prontos — dois cliques geram uma partida;
--  * cartão mostra nome, líder, forma do dono e estado textual (a cor nunca é a única pista);
--  * mudança de mapa, dificuldade ou composição limpa a prontidão (o servidor é quem limpa);
--  * no celular, lista vertical rolável e barra de prontidão fixa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)

local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local Modal = require(script.Parent.Parent.Modal)
local Store = require(script.Parent.Parent.Store)
local Toasts = require(script.Parent.Parent.Toasts)

local PartyScreen = {}
PartyScreen.__index = PartyScreen

local L = Localization.get

export type Callbacks = {
	onBack: () -> (),
	onEditTeam: () -> (),
	onInvite: () -> (),
	onStart: (mapId: string, difficulty: string) -> (),
	onLeft: () -> (),
}

export type PartyScreen = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		memberList: ScrollingFrame,
		footer: Frame,
		buttons: { Components.Button },
		startButton: Components.Button?,
		readyButton: Components.Button?,
	},
	PartyScreen
))

local OWNER_GLYPHS = { "●", "■", "▲", "◆" }

function PartyScreen.new(parent: Instance, callbacks: Callbacks): PartyScreen
	local self = setmetatable({ callbacks = callbacks, buttons = {} }, PartyScreen) :: any
	self.chrome = Chrome.new(parent, {
		name = "PartyScreen",
		title = L("party.title"),
		subtitle = L("party.subtitle"),
		onBack = callbacks.onBack,
	})
	local body = self.chrome.body
	self.memberList = Components.scroller(body, "Members", {
		Size = UDim2.new(1, 0, 1, -(Theme.sizes.buttonTarget + 22)),
		ZIndex = 2,
	})
	local layout = Components.list(self.memberList, Enum.FillDirection.Vertical, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	-- barra fixa: no celular ela não rola junto com a lista
	self.footer = Components.frame(body, "Footer", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 8),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget + 8)),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	Components.list(self.footer, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
	return self
end

local function localMember(party: { [string]: any }): { [string]: any }?
	for _, member in ipairs(party.members) do
		if member.userId == Players.LocalPlayer.UserId then
			return member
		end
	end
	return nil
end

local function memberCard(
	self: PartyScreen,
	party: { [string]: any },
	member: { [string]: any },
	index: number,
	isLeader: boolean
)
	local card = Components.panel(self.memberList, "M" .. member.userId, {
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = index,
		ZIndex = 3,
	}, { shadow = false, tape = member.userId == party.leaderId })
	Components.padding(card, 16, 12)

	local glyph = OWNER_GLYPHS[((index - 1) % 4) + 1]
	local ownerColor = Theme.owners[((index - 1) % 4) + 1].color
	Components.label(card, "Owner", glyph, {
		Size = UDim2.fromOffset(28, 28),
		TextColor3 = ownerColor,
		TextSize = 22,
		TextWrapped = false,
		ZIndex = 4,
	})
	Components.label(card, "Name", member.name, {
		Size = UDim2.new(1, -260, 0, 26),
		Position = UDim2.fromOffset(34, 0),
		Font = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.bodyLarge,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd, -- nome longo usa reticências; a ficha traz o completo
		ZIndex = 4,
	})

	local statusText = if member.userId == party.leaderId
		then L("party.leader")
		elseif member.ready then L("party.readyState")
		else L("party.waitingState")
	Components.caption(card, "Status", statusText, {
		Size = UDim2.new(0, 200, 0, 20),
		Position = UDim2.fromOffset(34, 28),
		TextColor3 = if member.ready or member.userId == party.leaderId
			then Theme.colors.tealDark
			else Theme.colors.muted,
		ZIndex = 4,
	})

	-- equipe congelada na largada; aqui é só leitura do loadout atual do integrante
	local names = {}
	for _, towerId in ipairs(member.loadout or {}) do
		local def = Catalog.getTower(towerId)
		table.insert(names, if def then def.name else towerId)
	end
	Components.caption(
		card,
		"Team",
		if #names > 0 then L("party.team", { team = table.concat(names, " · ") }) else L("menu.teamEmpty"),
		{
			Size = UDim2.new(1, -260, 0, 20),
			Position = UDim2.fromOffset(34, 50),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
		}
	)

	if not member.unlocked then
		Components.caption(card, "Locked", L("party.mapLocked"), {
			Size = UDim2.new(1, -260, 0, 18),
			Position = UDim2.fromOffset(34, 70),
			TextColor3 = Theme.colors.danger,
			ZIndex = 4,
		})
	end

	if isLeader and member.userId ~= Players.LocalPlayer.UserId then
		local kick = Components.button(card, {
			name = "Kick",
			text = L("menu.kick"),
			kind = "ghost",
			size = UDim2.fromOffset(150, Theme.sizes.buttonTarget),
			position = UDim2.new(1, -150, 0.5, -24),
			textSize = Theme.sizes.body,
			zIndex = 4,
			onActivate = function()
				Modal.open(self.chrome.root, {
					title = L("party.kickTitle"),
					body = L("party.kickBody", { name = member.name }),
					confirmText = L("party.kickConfirm", { name = member.name }),
					danger = true,
					onConfirm = function(controls)
						controls:setPending(true)
						CommandAdapter.send(
							"party:kick:" .. member.userId,
							"KickFromParty",
							{ userId = member.userId },
							{
								onSuccess = function()
									controls:close()
								end,
								onError = function(code)
									controls:setError(
										if Localization.has("error." .. code)
											then L("error." .. code)
											else L("error.UNKNOWN")
									)
								end,
							}
						)
					end,
				})
			end,
		})
		table.insert(self.buttons, kick)
	end
end

function PartyScreen.render(self: PartyScreen)
	self.chrome:refreshBalance()
	for _, button in ipairs(self.buttons) do
		button:destroy()
	end
	table.clear(self.buttons)
	for _, child in ipairs(self.memberList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in ipairs(self.footer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self.startButton = nil
	self.readyButton = nil

	local party = Store.party()
	if not party then
		Components.emptyState(self.memberList, "NoParty", L("party.none"), {
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 1,
		})
		self.chrome:setTitle(L("party.title"), L("party.subtitle"))
		return
	end

	local isLeader = party.leaderId == Players.LocalPlayer.UserId
	local map = Catalog.getMap(party.mapId)
	self.chrome:setTitle(
		L("party.title"),
		L("party.setup", {
			map = if map then map.name else party.mapId,
			difficulty = L("menu.difficulty." .. party.difficulty),
			size = #party.members,
			max = Balance.partyMax,
		})
	)

	for index, member in ipairs(party.members) do
		memberCard(self, party, member, index, isLeader)
	end
	for slot = #party.members + 1, Balance.partyMax do
		-- vaga livre é estado intencional: sem alerta, com ação de convite
		local empty = Components.panel(self.memberList, "Empty" .. slot, {
			Size = UDim2.new(1, 0, 0, 62),
			LayoutOrder = slot,
			BackgroundColor3 = Theme.colors.sage,
			ZIndex = 3,
		}, { shadow = false })
		Components.padding(empty, 16, 10)
		Components.label(empty, "Text", L("party.emptySlot"), {
			Size = UDim2.new(1, -180, 1, 0),
			TextColor3 = Theme.colors.muted,
			ZIndex = 4,
		})
		if #party.members < Balance.partyMax then
			table.insert(
				self.buttons,
				Components.button(empty, {
					name = "InviteSlot",
					text = L("menu.invite"),
					kind = "secondary",
					size = UDim2.fromOffset(160, Theme.sizes.buttonTarget),
					position = UDim2.new(1, -160, 0.5, -24),
					zIndex = 4,
					onActivate = self.callbacks.onInvite,
				})
			)
		end
	end

	-- rodapé fixo
	local me = localMember(party)
	table.insert(
		self.buttons,
		Components.button(self.footer, {
			name = "EditTeam",
			text = L("party.editTeam"),
			kind = "secondary",
			size = UDim2.fromOffset(240, Theme.sizes.buttonTarget),
			layoutOrder = 1,
			zIndex = 4,
			onActivate = self.callbacks.onEditTeam,
		})
	)
	table.insert(
		self.buttons,
		Components.button(self.footer, {
			name = "Leave",
			text = L("menu.leaveParty"),
			kind = "ghost",
			size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = 4,
			onActivate = function()
				CommandAdapter.send("party:leave", "LeaveParty", {}, {
					onSuccess = self.callbacks.onLeft,
					onError = function(code)
						Toasts.error(code)
					end,
				})
			end,
		})
	)

	if isLeader then
		local everyoneReady = true
		local blocked: string? = nil
		for _, member in ipairs(party.members) do
			if member.userId ~= party.leaderId and not member.ready then
				everyoneReady = false
			end
			if not member.unlocked then
				blocked = member.name
			end
		end
		local start = Components.button(self.footer, {
			name = "Start",
			text = L("menu.start"),
			kind = "primary",
			icon = "ui_play",
			size = UDim2.fromOffset(240, Theme.sizes.buttonTarget),
			layoutOrder = 3,
			zIndex = 4,
			onActivate = function()
				self.callbacks.onStart(party.mapId, party.difficulty)
			end,
		})
		if blocked then
			start:setAvailable(false, L("maps.memberLocked", { name = blocked }))
		elseif not everyoneReady then
			start:setAvailable(false, L("party.waitingReady"))
		end
		self.startButton = start
		table.insert(self.buttons, start)
	else
		local ready = me ~= nil and me.ready == true
		local button = Components.button(self.footer, {
			name = "Ready",
			text = if ready then L("party.cancelReady") else L("common.ready"),
			kind = if ready then "secondary" else "primary",
			size = UDim2.fromOffset(240, Theme.sizes.buttonTarget),
			layoutOrder = 3,
			zIndex = 4,
			onActivate = function()
				CommandAdapter.send("party:ready", "PartyReady", { ready = not ready }, {
					onError = function(code)
						Toasts.error(code)
					end,
				})
			end,
		})
		if me and not me.unlocked then
			button:setAvailable(false, L("party.youLocked"))
		end
		self.readyButton = button
		table.insert(self.buttons, button)
	end
end

function PartyScreen.setStartPending(self: PartyScreen, pending: boolean)
	if self.startButton then
		(self.startButton :: Components.Button):setPending(pending)
	end
end

function PartyScreen.show(self: PartyScreen)
	self.chrome:show()
	PartyScreen.render(self)
end

function PartyScreen.hide(self: PartyScreen)
	self.chrome:hide()
end

return PartyScreen
