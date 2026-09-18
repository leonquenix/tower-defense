--!strict
-- Orquestra as telas: camadas, roteamento, store do lobby, convites, carregamento de partida,
-- resultado, orientação e a ponte com o combate.
--
-- Uma tela principal por vez (Router), no máximo um painel contextual e um modal bloqueador acima.
-- Configurações abre de qualquer origem e volta para a mesma origem (Router.push/back).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Client = require(script.Parent.Parent.Net.Client)
local Responsive = require(script.Parent.Parent.View.Responsive)
local Accessibility = require(script.Parent.Parent.UI.Accessibility)
local CommandAdapter = require(script.Parent.Parent.UI.CommandAdapter)
local Focus = require(script.Parent.Parent.UI.Focus)
local InviteCards = require(script.Parent.Parent.UI.InviteCards)
local Layers = require(script.Parent.Parent.UI.Layers)
local Modal = require(script.Parent.Parent.UI.Modal)
local Router = require(script.Parent.Parent.UI.Router)
local Store = require(script.Parent.Parent.UI.Store)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Boot = require(script.Parent.Parent.UI.Screens.Boot)
local CollectionScreen = require(script.Parent.Parent.UI.Screens.CollectionScreen)
local Cosmetics = require(script.Parent.Parent.UI.Screens.Cosmetics)
local Invites = require(script.Parent.Parent.UI.Screens.Invites)
local MainMenu = require(script.Parent.Parent.UI.Screens.MainMenu)
local Maps = require(script.Parent.Parent.UI.Screens.Maps)
local MatchLoading = require(script.Parent.Parent.UI.Screens.MatchLoading)
local Orientation = require(script.Parent.Parent.UI.Screens.Orientation)
local PartyScreen = require(script.Parent.Parent.UI.Screens.PartyScreen)
local Rooms = require(script.Parent.Parent.UI.Screens.Rooms)
local ResultScreen = require(script.Parent.Parent.UI.Screens.ResultScreen)
local SettingsScreen = require(script.Parent.Parent.UI.Screens.SettingsScreen)
local ShopScreen = require(script.Parent.Parent.UI.Screens.ShopScreen)
local TowerDetail = require(script.Parent.Parent.UI.Screens.TowerDetail)
local MatchController = require(script.Parent.MatchController)
local PlayController = require(script.Parent.PlayController)
local SettingsController = require(script.Parent.SettingsController)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)

local ScreenController = {}

local L = Localization.get

local menuLayer: Frame
local hudLayer: Frame
local modalLayer: Frame

local boot: Boot.Boot
local mainMenu: MainMenu.MainMenu
local maps: Maps.Maps
local rooms: Rooms.Rooms
local party: PartyScreen.PartyScreen
local collection: CollectionScreen.CollectionScreen
local towerDetail: TowerDetail.TowerDetail
local cosmetics: Cosmetics.Cosmetics
local shop: ShopScreen.ShopScreen
local settings: SettingsScreen.SettingsScreen
local invites: Invites.Invites
local matchLoading: MatchLoading.MatchLoading
local result: ResultScreen.ResultScreen
local orientation: Orientation.Orientation

local inMatch = false
local settingsApplied = false
local waitingMatch = false

local function toastError(code: string?)
	Toasts.error(code)
end

-- ---------------------------------------------------------------------------
-- Início de partida
-- ---------------------------------------------------------------------------

local function startMatch(mapId: string, difficulty: string, matchMode: string)
	if CommandAdapter.isPending("match:start") then
		return -- "Começar" duplicado gera uma só partida
	end
	local profile = Store.profile()
	local loadout: { string } = if profile and profile.loadout
		then table.clone(profile.loadout)
		else Catalog.starterTowerIds()
	PlayController.pendingLoadout = loadout
	waitingMatch = true
	Router.suspend()
	matchLoading:show(if matchMode == "tutorial" then "jardim" else mapId, difficulty, loadout)
	party:setStartPending(true)
	CommandAdapter.send("match:start", "StartMatch", { mapId = mapId, mode = difficulty, matchMode = matchMode }, {
		onSuccess = function()
			party:setStartPending(false)
		end,
		onError = function(code, response)
			party:setStartPending(false)
			waitingMatch = false
			matchLoading:hide()
			Router.resume()
			if response.reason == "map_locked" then
				Toasts.error("INVALID_STATE")
				Toasts.show(L("menu.notAllUnlocked"), "error", "start:map_locked")
			elseif response.reason == "not_ready" then
				Toasts.show(L("party.waitingReady"), "error", "start:not_ready")
			elseif response.reason == "empty_loadout" then
				Toasts.show(L("menu.teamEmpty"), "error", "start:empty_loadout")
			else
				toastError(code)
			end
		end,
	})
end

-- ---------------------------------------------------------------------------
-- Lobby e convites
-- ---------------------------------------------------------------------------

local function refreshVisibleScreen()
	local current = Router.current()
	if current == "menu" then
		mainMenu:render()
	elseif current == "maps" then
		maps:render()
	elseif current == "rooms" then
		rooms:render()
	elseif current == "party" then
		party:render()
	elseif current == "collection" then
		collection:render()
	elseif current == "tower" then
		towerDetail:render()
	elseif current == "cosmetics" then
		cosmetics:render()
	elseif current == "invites" then
		invites:render()
	end
end

local function applyLobby(data: { [string]: any })
	Store.setLobby(data)
	local profile = data.profile
	if profile and (profile.status == "ready" or profile.status == "volatile") then
		if not settingsApplied and profile.settings then
			settingsApplied = true
			SettingsController.apply(profile.settings)
		end
		if profile.loadout then
			PlayController.pendingLoadout = table.clone(profile.loadout)
		end
	end
	-- perfil pronto e fora de partida: sai da tela de entrada
	if Router.current() == nil or Router.current() == "boot" then
		if Store.profile() and not data.inMatch and not MatchController.inMatch() then
			boot:hide()
			Router.reset("menu")
			AudioController.music("music_menu")
		end
	end
	refreshVisibleScreen()
end

-- ---------------------------------------------------------------------------
-- Registro das telas
-- ---------------------------------------------------------------------------

local function openSettings()
	Router.push("settings", { inMatch = inMatch })
end

local function registerScreens()
	Router.register("boot", {
		show = function()
			boot:show()
		end,
		hide = function()
			boot:hide()
		end,
	})
	Router.register("menu", {
		show = function()
			mainMenu:show()
		end,
		hide = function()
			mainMenu:hide()
		end,
		resume = function()
			mainMenu:show()
		end,
	})
	Router.register("maps", {
		show = function()
			maps:show()
		end,
		hide = function()
			maps:hide()
		end,
		resume = function()
			maps:show()
		end,
	})
	Router.register("rooms", {
		show = function()
			rooms:show()
		end,
		hide = function()
			rooms:hide()
		end,
		resume = function()
			rooms:show()
		end,
	})
	Router.register("party", {
		show = function()
			party:show()
		end,
		hide = function()
			party:hide()
		end,
		resume = function()
			party:show()
		end,
	})
	Router.register("collection", {
		show = function()
			collection:show()
		end,
		hide = function()
			collection:hide()
		end,
		-- ao voltar do detalhe, a seleção e o rascunho da equipe continuam onde estavam
		resume = function()
			collection:resume()
		end,
	})
	Router.register("tower", {
		show = function(params)
			towerDetail:show(params)
		end,
		hide = function()
			towerDetail:hide()
		end,
		resume = function(params)
			towerDetail:show(params)
		end,
	})
	Router.register("cosmetics", {
		show = function(params)
			cosmetics:show(params)
		end,
		hide = function()
			cosmetics:hide()
		end,
	})
	Router.register("shop", {
		show = function()
			shop:show()
		end,
		hide = function()
			shop:hide()
		end,
	})
	Router.register("settings", {
		show = function(params)
			settings:show(params)
		end,
		hide = function()
			settings:hide()
		end,
	})
	Router.register("invites", {
		show = function()
			invites:show()
		end,
		hide = function()
			invites:hide()
		end,
		resume = function()
			invites:show()
		end,
	})
end

local function buildScreens()
	boot = Boot.new(menuLayer, {
		onTraining = function()
			startMatch("jardim", "normal", "training")
		end,
		onSettings = openSettings,
	})

	mainMenu = MainMenu.new(menuLayer, {
		onPlay = function()
			Router.go("maps")
		end,
		onCollection = function()
			Router.go("collection")
		end,
		onTraining = function()
			local mapId = maps:selection()
			startMatch(mapId, "normal", "training")
		end,
		onSettings = openSettings,
		onTutorial = function()
			startMatch("jardim", "normal", "tutorial")
		end,
		onShop = function()
			Router.push("shop")
		end,
		onRetryProfile = function()
			CommandAdapter.send("boot:retry", "RetryProfile", {}, nil)
		end,
	})

	maps = Maps.new(menuLayer, {
		onBack = function()
			Router.go("menu")
		end,
		onSolo = function(mapId, difficulty)
			startMatch(mapId, difficulty, "normal")
		end,
		onFriends = function()
			Router.go("rooms")
		end,
		onSelectionChanged = function(mapId, difficulty)
			-- em grupo, o líder propaga a escolha; o servidor limpa a prontidão
			if Store.party() then
				CommandAdapter.send("party:setup", "PartySetup", { mapId = mapId, mode = difficulty }, {
					onError = function(code)
						if code ~= "NOT_OWNER" then
							toastError(code)
						end
					end,
				})
			end
		end,
	})

	rooms = Rooms.new(menuLayer, {
		onBack = function()
			Router.go("maps")
		end,
		onJoined = function()
			Router.go("party")
		end,
		onCreated = function()
			Router.go("party")
		end,
		onSolo = function()
			local mapId, difficulty = maps:selection()
			startMatch(mapId, difficulty, "normal")
		end,
		onInvite = function()
			Router.push("invites")
		end,
	})

	party = PartyScreen.new(menuLayer, {
		onBack = function()
			Router.go("maps")
		end,
		onEditTeam = function()
			Router.push("collection")
		end,
		onInvite = function()
			Router.push("invites")
		end,
		onStart = function(mapId, difficulty)
			startMatch(mapId, difficulty, "normal")
		end,
		onLeft = function()
			Router.go("maps")
		end,
	})

	collection = CollectionScreen.new(menuLayer, {
		onBack = function()
			if not Router.back() then
				Router.go("menu")
			end
		end,
		onOpenTower = function(towerId)
			Router.push("tower", { towerId = towerId })
		end,
		onSaved = function()
			refreshVisibleScreen()
		end,
	})

	towerDetail = TowerDetail.new(menuLayer, {
		onBack = function()
			if not Router.back() then
				Router.go("collection")
			end
		end,
		onEquip = function(towerId)
			Router.backTo("collection")
			collection:equipFromDetail(towerId)
		end,
		onCosmetics = function(towerId)
			Router.push("cosmetics", { towerId = towerId })
		end,
		onTraining = function()
			startMatch("jardim", "normal", "training")
		end,
		onUnlocked = function()
			refreshVisibleScreen()
		end,
	})

	cosmetics = Cosmetics.new(menuLayer, {
		onBack = function()
			if not Router.back() then
				Router.go("collection")
			end
		end,
		onShop = function()
			Router.push("shop")
		end,
	})

	shop = ShopScreen.new(menuLayer, {
		onBack = function()
			if not Router.back() then
				Router.go("menu")
			end
		end,
		onCosmetics = function()
			Router.backTo("collection")
		end,
		onShopState = function(enabled)
			mainMenu:setShopEnabled(enabled)
			cosmetics:setShopEnabled(enabled)
		end,
	})

	settings = SettingsScreen.new(menuLayer, {
		onDone = function()
			if not Router.back() then
				Router.go("menu")
			end
		end,
	})

	invites = Invites.new(menuLayer, {
		onBack = function()
			if not Router.back() then
				Router.go("rooms")
			end
		end,
	})

	matchLoading = MatchLoading.new(menuLayer, {
		onBack = function()
			-- respeita o estado real da partida: só volta para o menu, nada é cancelado aqui
			waitingMatch = false
			matchLoading:hide()
			Router.resume()
		end,
	})

	result = ResultScreen.new(modalLayer, {
		onRematch = function(ready)
			MatchController.command("Rematch", { ready = ready }, function(response)
				if not response.ok then
					toastError(response.errorCode)
				end
			end)
		end,
		onMenu = function()
			result:hide()
			MatchController.command("LeaveMatch", {}, nil)
		end,
		onOpenCollection = function()
			result:hide()
			Router.go("collection")
		end,
		onOpenMaps = function()
			result:hide()
			Router.go("maps")
		end,
		onOpenMastery = function(towerId)
			result:hide()
			Router.go("collection")
			Router.push("cosmetics", { towerId = towerId })
		end,
	})

	orientation = Orientation.new(modalLayer, {
		onSettings = openSettings,
		onMenu = function()
			if inMatch then
				Modal.open(modalLayer, {
					title = L("hud.leave"),
					body = L("hud.leaveConfirm"),
					confirmText = L("hud.leave"),
					danger = true,
					onConfirm = function(controls)
						controls:setPending(true)
						MatchController.command("LeaveMatch", {}, function()
							controls:close()
						end)
					end,
				})
			else
				Router.go("menu")
			end
		end,
	})
end

-- ---------------------------------------------------------------------------
-- Inicialização
-- ---------------------------------------------------------------------------

function ScreenController.init(playerGui: PlayerGui)
	Responsive.init()
	Accessibility.init()
	Layers.init(playerGui)
	Focus.init()

	menuLayer = Layers.content("menu")
	hudLayer = Layers.content("hud")
	modalLayer = Layers.content("modal")
	Modal.setHost(modalLayer)
	Toasts.init(Layers.content("toast"))
	InviteCards.init(Layers.content("toast"), function()
		if not inMatch then
			Router.go("party")
		end
	end)

	buildScreens()
	registerScreens()

	PlayController.init(hudLayer, {
		onLeft = function()
			inMatch = false
			collection:setReadOnly(false)
			result:hide()
			Router.reset("menu")
			AudioController.music("music_menu")
			-- reconcilia recompensas registradas que ainda não foram creditadas
			CommandAdapter.send("result:claim", "ClaimPending", {}, {
				onSuccess = function(response)
					if response.profile then
						Store.setProfile(response.profile)
					end
					refreshVisibleScreen()
				end,
			})
		end,
		onResult = function(payload)
			result:show(payload)
		end,
		onOpenSettings = openSettings,
	})

	MatchController.on("start", function()
		inMatch = true
		waitingMatch = false
		collection:setReadOnly(true)
		matchLoading:hide()
		Router.suspend()
		result:hide()
	end)
	MatchController.on("frame", function()
		Store.noteFrame()
	end)
	MatchController.on("rematch", function(ready, total)
		result:setRematch(ready, total)
	end)

	Client.onLobby(function(kind: string, payload: any)
		if kind == "lobby" then
			applyLobby(payload)
		elseif kind == "invite" then
			-- cartão discreto: não rouba foco e não interrompe o combate
			Store.addInvite({
				inviteId = tostring(payload.inviteId),
				partyId = tostring(payload.partyId),
				fromUserId = payload.fromUserId,
				fromName = tostring(payload.fromName),
				mapId = payload.mapId,
				difficulty = payload.difficulty,
				expiresAt = os.clock() + (payload.expiresIn or 30),
				state = "pending",
			})
		end
	end)

	Responsive.onChange(function(_, modeChanged)
		Layers.applyScale()
		PlayController.relayout()
		mainMenu:relayout()
		if modeChanged then
			refreshVisibleScreen()
		end
	end)

	Accessibility.onChange(function()
		refreshVisibleScreen()
	end)
	SettingsController.onChanged(function(current)
		Accessibility.setGamePreferences(current.reducedMotion, current.reducedParticles)
	end)
	Accessibility.setGamePreferences(SettingsController.get().reducedMotion, SettingsController.get().reducedParticles)

	Router.reset("boot")

	-- Um único laço de apresentação: convites, entrada, carregamento, conexão e orientação.
	-- Nada de um loop por botão ou contador.
	local accumulator = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local now = os.clock()
		InviteCards.update(now)
		if Router.current() == "boot" then
			boot:update()
		end
		if waitingMatch then
			matchLoading:update()
		end
		if inMatch then
			Store.updateConnection(now)
		end
		local portrait = InputController.isPortrait() and InputController.isTouchDevice()
		orientation:setVisible(portrait, inMatch)
	end)
end

function ScreenController.currentScreen(): string
	if inMatch then
		return "play"
	end
	return Router.current() or "boot"
end

function ScreenController.isInMatch(): boolean
	return inMatch
end

return ScreenController
