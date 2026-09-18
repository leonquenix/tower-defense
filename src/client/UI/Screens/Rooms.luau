--!strict
-- 04_salas: encontrar pessoas presentes neste servidor.
--
-- Contrato:
--  * "Entrar" pede uma vaga atômica; a resposta do servidor manda, e a lista permanece;
--  * duas entradas simultâneas são impedidas (um pedido pendente por vez);
--  * estados: carregando, lista, vazia (com Criar sala e Jogar solo), cheia, já em partida e erro;
--  * nada de fila global falsa: a lista é só deste servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.Parent.View.Theme)
local Components = require(script.Parent.Parent.Components)
local CommandAdapter = require(script.Parent.Parent.CommandAdapter)
local Chrome = require(script.Parent.Chrome)
local Store = require(script.Parent.Parent.Store)

local Rooms = {}
Rooms.__index = Rooms

local L = Localization.get

export type Callbacks = {
	onBack: () -> (),
	onJoined: () -> (),
	onCreated: () -> (),
	onSolo: () -> (),
	onInvite: () -> (),
}

export type Rooms = typeof(setmetatable(
	{} :: {
		chrome: Chrome.Screen,
		callbacks: Callbacks,
		list: ScrollingFrame,
		buttons: { Components.Button },
		errorLabel: TextLabel,
		joiningId: string?,
	},
	Rooms
))

function Rooms.new(parent: Instance, callbacks: Callbacks): Rooms
	local self = setmetatable({ callbacks = callbacks, buttons = {}, joiningId = nil }, Rooms) :: any
	self.chrome = Chrome.new(parent, {
		name = "RoomsScreen",
		title = L("rooms.title"),
		subtitle = L("rooms.subtitle"),
		onBack = callbacks.onBack,
	})
	local body = self.chrome.body
	self.errorLabel = Components.label(body, "Error", "", {
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.colors.danger,
		Font = Theme.fonts.bodyMedium,
		TextSize = Theme.sizes.caption,
		Visible = false,
		ZIndex = 3,
	})
	self.list = Components.scroller(body, "List", {
		Size = UDim2.new(1, 0, 1, -(Theme.sizes.buttonTarget + 40)),
		Position = UDim2.fromOffset(0, 26),
		ZIndex = 2,
	})
	local layout = Components.list(self.list, Enum.FillDirection.Vertical, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local footer = Components.frame(body, "Footer", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 6),
		Position = UDim2.new(0, 0, 1, -(Theme.sizes.buttonTarget + 6)),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	Components.list(footer, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	table.insert(
		self.buttons,
		Components.button(footer, {
			name = "Invite",
			text = L("rooms.invitePresent"),
			kind = "secondary",
			icon = "ui_group",
			size = UDim2.fromOffset(270, Theme.sizes.buttonTarget),
			layoutOrder = 1,
			zIndex = 3,
			onActivate = callbacks.onInvite,
		})
	)
	table.insert(
		self.buttons,
		Components.button(footer, {
			name = "Create",
			text = L("menu.createParty"),
			kind = "primary",
			size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
			layoutOrder = 2,
			zIndex = 3,
			onActivate = function()
				Rooms.create(self)
			end,
		})
	)
	return self
end

function Rooms.create(self: Rooms)
	if CommandAdapter.isPending("party:create") then
		return
	end
	CommandAdapter.send("party:create", "CreateParty", {}, {
		onSuccess = function()
			self.callbacks.onCreated()
		end,
		onError = function(code)
			Rooms.setError(self, code)
		end,
	})
end

function Rooms.setError(self: Rooms, code: string?)
	if not code then
		self.errorLabel.Visible = false
		return
	end
	local key = "error." .. code
	self.errorLabel.Text = if Localization.has(key) then L(key) else L("error.UNKNOWN")
	self.errorLabel.Visible = true
end

-- Uma entrada por vez: o botão clicado fica pendente e os outros ficam indisponíveis.
function Rooms.join(self: Rooms, roomId: string, button: Components.Button)
	if self.joiningId then
		return
	end
	self.joiningId = roomId
	button:setPending(true)
	local started = CommandAdapter.send("party:join", "JoinParty", { partyId = roomId }, {
		onSuccess = function()
			self.joiningId = nil
			button:setPending(false)
			self.callbacks.onJoined()
		end,
		onError = function(code)
			self.joiningId = nil
			button:setPending(false)
			-- a vaga pode ter sumido entre o snapshot e o clique: explica e mantém a lista
			button:showError(if code == "INVALID_STATE" then L("rooms.full") else L("common.retry"))
			Rooms.setError(self, code)
			Rooms.render(self)
		end,
	})
	if not started then
		self.joiningId = nil
		button:setPending(false)
	end
end

function Rooms.render(self: Rooms)
	self.chrome:refreshBalance()
	for index = #self.buttons, 1, -1 do
		local button = self.buttons[index]
		if button.instance.Parent == self.list then
			button:destroy()
			table.remove(self.buttons, index)
		end
	end
	for _, child in ipairs(self.list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local state = Store.get()
	local rooms = Store.rooms()
	local party = Store.party()

	if state.lobby == nil then
		Components.emptyState(self.list, "Loading", L("app.loading"), {
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 1,
		})
		return
	end
	if state.lobby.inMatch then
		Components.emptyState(self.list, "InMatch", L("menu.matchInProgress"), {
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 1,
		})
		return
	end

	local shown = 0
	for index, room in ipairs(rooms) do
		if not party or room.id ~= party.id then
			shown += 1
			local map = Catalog.getMap(room.mapId)
			local card = Components.panel(self.list, "Room_" .. room.id, {
				Size = UDim2.new(1, 0, 0, 84),
				LayoutOrder = index,
				ZIndex = 3,
			}, { shadow = false, tape = true })
			Components.padding(card, 16, 12)
			Components.label(card, "Leader", L("menu.partyOf", { leader = room.leaderName }), {
				Size = UDim2.new(1, -220, 0, 24),
				Font = Theme.fonts.bodyBold,
				TextSize = Theme.sizes.bodyLarge,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 4,
			})
			Components.caption(
				card,
				"Detail",
				string.format(
					"%s · %s · %d/%d",
					if map then map.name else room.mapId,
					L("menu.difficulty." .. room.difficulty),
					room.size,
					Balance.partyMax
				),
				{
					Size = UDim2.new(1, -220, 0, 20),
					Position = UDim2.fromOffset(0, 26),
					TextWrapped = false,
					ZIndex = 4,
				}
			)
			local full = room.size >= Balance.partyMax
			local join: Components.Button
			join = Components.button(card, {
				name = "Join",
				text = L("rooms.join"),
				kind = "primary",
				size = UDim2.fromOffset(185, Theme.sizes.buttonTarget),
				position = UDim2.new(1, -185, 0.5, -24),
				zIndex = 4,
				onActivate = function()
					Rooms.join(self, room.id, join)
				end,
			})
			if party then
				join:setAvailable(false, L("rooms.alreadyInParty"))
			elseif full then
				join:setAvailable(false, L("rooms.full"))
			elseif self.joiningId then
				join:setAvailable(false, L("rooms.joining"))
			end
			table.insert(self.buttons, join)
		end
	end

	if shown == 0 then
		-- estado vazio: caminho claro para criar sala ou jogar solo, sem alerta vermelho
		local empty = Components.panel(self.list, "Empty", {
			Size = UDim2.new(1, 0, 0, 150),
			LayoutOrder = 1,
			ZIndex = 3,
		}, { shadow = false })
		Components.padding(empty, 20, 18)
		local layout = Components.list(empty, Enum.FillDirection.Vertical, 12)
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		Components.label(empty, "Text", L("menu.noRooms"), {
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = 1,
			ZIndex = 4,
		})
		local row = Components.frame(empty, "Row", {
			Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			ZIndex = 4,
		})
		Components.list(row, Enum.FillDirection.Horizontal, 12)
		table.insert(
			self.buttons,
			Components.button(row, {
				name = "EmptyCreate",
				text = L("menu.createParty"),
				kind = "primary",
				size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
				layoutOrder = 1,
				zIndex = 5,
				onActivate = function()
					Rooms.create(self)
				end,
			})
		)
		table.insert(
			self.buttons,
			Components.button(row, {
				name = "EmptySolo",
				text = L("maps.solo"),
				kind = "secondary",
				size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
				layoutOrder = 2,
				zIndex = 5,
				onActivate = self.callbacks.onSolo,
			})
		)
	end
end

function Rooms.show(self: Rooms)
	self.chrome:show()
	Rooms.setError(self, nil)
	Rooms.render(self)
end

function Rooms.hide(self: Rooms)
	self.chrome:hide()
	self.joiningId = nil
end

return Rooms
