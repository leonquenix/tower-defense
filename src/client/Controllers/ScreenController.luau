--!strict
-- Navegação entre telas: carregando, menu, coleção, configurações, loja, partida e resultado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Theme = require(script.Parent.Parent.View.Theme)
local Ui = require(script.Parent.Parent.View.Ui)
local Menu = require(script.Parent.Parent.View.Menu)
local Collection = require(script.Parent.Parent.View.Collection)
local Settings = require(script.Parent.Parent.View.Settings)
local Result = require(script.Parent.Parent.View.Result)
local Shop = require(script.Parent.Parent.View.Shop)
local Client = require(script.Parent.Parent.Net.Client)
local MatchController = require(script.Parent.MatchController)
local PlayController = require(script.Parent.PlayController)
local SettingsController = require(script.Parent.SettingsController)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)
local Responsive = require(script.Parent.Parent.View.Responsive)
local TweenService = game:GetService("TweenService")

local ScreenController = {}

local L = Localization.get

local layer: Frame
local loading: Frame
local orientationHint: Frame
local curtain: Frame
local uiScale: UIScale
local menu: Menu.Menu
local collection: Collection.Collection
local settings: Settings.Settings
local result: Result.Result
local shop: Shop.Shop
local current = "loading"
local lobby: Menu.LobbyData? = nil
local settingsApplied = false

local function hideAll()
	loading.Visible = false
	menu:hide()
	collection:hide()
	settings:hide()
	shop:hide()
end

-- Transição com cortina curta entre telas (imediata no movimento reduzido)
local function transition(apply: () -> ())
	if Ui.isReducedMotion() or not curtain or current == "loading" then
		apply()
		return
	end
	curtain.Visible = true
	curtain.Active = true
	local fadeIn =
		TweenService:Create(curtain, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Once(function()
		apply()
		local fadeOut =
			TweenService:Create(curtain, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Once(function()
			curtain.Visible = false
			curtain.Active = false
		end)
	end)
end

local function show(name: string)
	transition(function()
		current = name
		hideAll()
		if name == "menu" then
			menu:show()
		elseif name == "collection" then
			collection:show()
		elseif name == "settings" then
			settings:show()
		elseif name == "shop" then
			shop:show()
		elseif name == "loading" then
			loading.Visible = true
		end
	end)
end

local function toastError(code: string?)
	Ui.toast(layer, L("error." .. (code or "INVALID_STATE")), true)
end

local function startMatch(mapId: string, difficulty: string, matchMode: string)
	local profile = lobby and lobby.profile
	if profile and profile.loadout then
		PlayController.pendingLoadout = table.clone(profile.loadout)
	end
	Client.requestAsync("StartMatch", { mapId = mapId, mode = difficulty, matchMode = matchMode }, function(response)
		if not response.ok then
			if response.reason == "map_locked" then
				Ui.toast(layer, L("menu.notAllUnlocked"), true)
			elseif response.reason == "not_ready" then
				Ui.toast(layer, L("common.notReady"), true)
			else
				toastError(response.errorCode)
			end
		end
	end)
end

local function applyLobby(data: Menu.LobbyData)
	lobby = data
	menu:setLobby(data)
	local profile = data.profile
	if profile and (profile.status == "ready" or profile.status == "volatile") then
		collection:setProfile(profile)
		if not settingsApplied and profile.settings then
			settingsApplied = true
			SettingsController.apply(profile.settings)
			-- textos dependem do idioma: re-renderiza
			menu:setLobby(data)
		end
		if profile.loadout then
			PlayController.pendingLoadout = table.clone(profile.loadout)
		end
	end
	if current == "loading" and not MatchController.inMatch() and not data.inMatch then
		show("menu")
		AudioController.music("music_menu")
	end
end

function ScreenController.init(gui: ScreenGui)
	Responsive.init()
	layer = Ui.frame(gui, "Screens", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	uiScale = Instance.new("UIScale")
	uiScale.Parent = layer
	local function applyResponsive()
		local state = Responsive.get()
		uiScale.Scale = state.scale
		layer.Size = UDim2.fromScale(1 / state.scale, 1 / state.scale)
	end
	applyResponsive()
	curtain = Ui.frame(gui, "Curtain", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.paper,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 80,
	})
	loading = Ui.frame(layer, "Loading", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.paper })
	Ui.title(loading, "Title", L("app.title"), {
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromScale(0, 0.4),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 40,
	})
	Ui.label(loading, "Sub", L("app.loading"), {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromScale(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.muted,
	})

	menu = Menu.new(layer, {
		onStart = startMatch,
		onCollection = function()
			show("collection")
		end,
		onSettings = function()
			show("settings")
		end,
		onShop = function()
			show("shop")
		end,
		onCreateParty = function()
			Client.requestAsync("CreateParty", {}, function(r)
				if not r.ok then
					toastError(r.errorCode)
				end
			end)
		end,
		onJoinParty = function(partyId)
			Client.requestAsync("JoinParty", { partyId = partyId }, function(r)
				if not r.ok then
					toastError(r.errorCode)
				end
			end)
		end,
		onLeaveParty = function()
			Client.requestAsync("LeaveParty", {}, nil)
		end,
		onPartyReady = function(ready)
			Client.requestAsync("PartyReady", { ready = ready }, nil)
		end,
		onPartySetup = function(mapId, difficulty)
			Client.requestAsync("PartySetup", { mapId = mapId, mode = difficulty }, nil)
		end,
		onInvite = function(userId)
			Client.requestAsync("InviteToParty", { userId = userId }, function(r)
				if r.ok then
					Ui.toast(layer, L("menu.invite") .. " ✓")
				else
					toastError(r.errorCode)
				end
			end)
		end,
		onKick = function(userId)
			Client.requestAsync("KickFromParty", { userId = userId }, nil)
		end,
		onRetryProfile = function()
			Client.requestAsync("RetryProfile", {}, nil)
		end,
	})
	collection = Collection.new(layer, {
		onBack = function()
			show("menu")
		end,
		onBuy = function(towerId)
			Client.requestAsync("BuyTower", { towerId = towerId }, function(r)
				if r.ok then
					AudioController.play("unlock", true)
					if r.profile then
						collection:setProfile(r.profile)
					end
				else
					toastError(r.errorCode)
				end
			end)
		end,
		onSetLoadout = function(towerIds)
			Client.requestAsync("SetLoadout", { towerIds = towerIds }, function(r)
				if r.ok then
					if r.profile then
						collection:setProfile(r.profile)
						PlayController.pendingLoadout = table.clone(r.profile.loadout)
					end
				else
					toastError(r.errorCode)
				end
			end)
		end,
	})
	settings = Settings.new(layer, {
		onBack = function()
			show("menu")
		end,
		onSave = function(s: Types.ProfileSettings)
			Client.requestAsync("SaveSettings", {
				musicVolume = s.musicVolume,
				sfxVolume = s.sfxVolume,
				reducedMotion = s.reducedMotion,
				reducedParticles = s.reducedParticles,
				damageNumbers = s.damageNumbers,
				circuitPattern = s.circuitPattern,
				locale = s.locale,
			}, nil)
		end,
	})
	shop = Shop.new(layer, {
		onBack = function()
			show("menu")
		end,
		onQuery = function(callback)
			Client.requestAsync("QueryShop", {}, function(r)
				callback(r)
			end)
		end,
		onBuy = function()
			Client.requestAsync("PromptFounderPass", {}, function(r)
				if not r.ok then
					toastError(r.errorCode)
				end
			end)
		end,
	})
	result = Result.new(layer, {
		onRematch = function(ready)
			MatchController.command("Rematch", { ready = ready }, nil)
		end,
		onMenu = function()
			result:hide()
			MatchController.command("LeaveMatch", {}, nil)
		end,
	})
	PlayController.init(layer, {
		onLeft = function()
			result:hide()
			show("menu")
			Client.requestAsync("ClaimPending", {}, nil)
		end,
		onResult = function(payload)
			result:show(payload)
		end,
	})
	MatchController.on("start", function()
		transition(function()
			hideAll()
			result:hide()
			current = "play"
		end)
	end)
	Responsive.onChange(function(_, modeChanged)
		applyResponsive()
		PlayController.relayout()
		menu:relayout()
		collection.refit()
		if modeChanged and current == "menu" then
			menu:render()
		end
	end)
	MatchController.on("rematch", function(ready, total)
		result:setRematch(ready, total)
	end)
	Client.onLobby(function(kind, payload)
		if kind == "lobby" then
			applyLobby(payload)
		elseif kind == "invite" then
			Ui.confirm(
				layer,
				L("menu.joinParty"),
				L("menu.partyOf", { leader = payload.fromName }),
				L("menu.joinParty"),
				L("common.cancel"),
				false,
				function()
					Client.requestAsync("JoinParty", { partyId = payload.partyId }, nil)
				end
			)
		end
	end)

	-- orientação vertical: pedir para girar, mantendo acesso a configurações
	orientationHint = Ui.frame(
		gui,
		"Orientation",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.colors.ink, Visible = false, ZIndex = 90 }
	)
	Ui.label(orientationHint, "Text", "⟳  " .. L("orientation.rotate"), {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromScale(0, 0.45),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.cream,
		TextSize = 22,
		Font = Theme.fonts.title,
	})
	RunService.RenderStepped:Connect(function()
		local portrait = InputController.isPortrait() and InputController.isTouchDevice()
		if orientationHint.Visible ~= portrait then
			orientationHint.Visible = portrait
		end
	end)

	show("loading")
end

function ScreenController.currentScreen(): string
	return current
end

return ScreenController
