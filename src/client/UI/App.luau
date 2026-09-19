--!strict
-- Raiz da interface: cria as camadas (ScreenGui), monta as telas e mantém o relógio curto que
-- faz convites, avisos e conexão envelhecerem.
--
-- Camadas (decisão local, não substitui a CoreGui):
--   world  0  cenário decorativo, sem área clicável
--   hud   10  tabuleiro e combate
--   menu  20  telas de menu
--   modal 30  modais bloqueadores e resultado
--   toast 40  avisos curtos
--
-- Trocar de idioma reescreve texto já desenhado, então a árvore inteira é remontada: é mais
-- honesto do que tentar atualizar cada rótulo no lugar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiTokens = require(ReplicatedStorage.Shared.Config.UiTokens)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Actions = require(script.Parent.Parent.State.Actions)
local Atoms = require(script.Parent.Parent.State.Atoms)
local Bridge = require(script.Parent.Parent.State.Bridge)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local Responsive = require(script.Parent.Parent.View.Responsive)
local Skin = require(script.Parent.Skin)
local Kit = require(script.Parent.Kit)
local Accessibility = require(script.Parent.Accessibility)
local InviteCards = require(script.Parent.Overlays.InviteCards)
local ModalHost = require(script.Parent.Overlays.ModalHost)
local Orientation = require(script.Parent.Overlays.Orientation)
local Toasts = require(script.Parent.Overlays.Toasts)
local Boot = require(script.Parent.Screens.Boot)
local Collection = require(script.Parent.Screens.Collection)
local Cosmetics = require(script.Parent.Screens.Cosmetics)
local Hud = require(script.Parent.Screens.Hud)
local Invites = require(script.Parent.Screens.Invites)
local Loading = require(script.Parent.Screens.Loading)
local MainMenu = require(script.Parent.Screens.MainMenu)
local Maps = require(script.Parent.Screens.Maps)
local Party = require(script.Parent.Screens.Party)
local Result = require(script.Parent.Screens.Result)
local Rooms = require(script.Parent.Screens.Rooms)
local Settings = require(script.Parent.Screens.Settings)
local Shop = require(script.Parent.Screens.Shop)

local Children = Fusion.Children

local App = {}

export type Options = {
	playerGui: PlayerGui,
	localUserId: number,
	-- Chamado a cada montagem com o Frame onde o tabuleiro deve ser desenhado.
	onBoardArea: (Frame) -> (),
}

local scope: Kit.Scope? = nil
local options: Options? = nil
local ticking = false

local function makeGui(playerGui: PlayerGui, name: string, order: number, interactive: boolean): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = order
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	-- só as camadas interativas respeitam a área segura; a decorativa cobre a tela inteira
	gui.ScreenInsets = if interactive then Enum.ScreenInsets.CoreUISafeInsets else Enum.ScreenInsets.None
	gui.Parent = playerGui
	return gui
end

-- O conteúdo é desenhado na resolução de referência e escalado por um UIScale, então o layout
-- continua sendo escrito em pixels de 1280x720.
local function scaledContent(currentScope: Kit.Scope, gui: ScreenGui, children: { any }): Frame
	local state = Responsive.get()
	local content = currentScope:New("Frame")({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1 / state.scale, 1 / state.scale),
		[Children] = Kit.children(currentScope:New("UIScale")({ Scale = state.scale }), table.unpack(children)),
	})
	content.Parent = gui
	return content
end

local function routeIs(currentScope: Kit.Scope, route: Atoms.Route): Fusion.Computed<boolean>
	local atom = Bridge.use(currentScope, Atoms.route)
	return currentScope:Computed(function(use)
		return use(atom) == route
	end)
end

function App.mount()
	local opts = options
	if not opts then
		return
	end
	if scope then
		Fusion.doCleanup(scope)
	end
	local currentScope = Kit.scope()
	scope = currentScope

	local order = UiTokens.displayOrder
	local worldGui = makeGui(opts.playerGui, "QuintalWorld", order.world, false)
	local hudGui = makeGui(opts.playerGui, "QuintalHud", order.hud, true)
	local menuGui = makeGui(opts.playerGui, "QuintalMenu", order.menu, true)
	local modalGui = makeGui(opts.playerGui, "QuintalModal", order.modal, true)
	local toastGui = makeGui(opts.playerGui, "QuintalToast", order.toast, true)

	-- cenário ilustrado: desenho imperativo (não tem estado nem interação)
	local world = currentScope:New("Frame")({
		Name = "World",
		BackgroundColor3 = Color3.fromRGB(15, 42, 30),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	})
	world.Parent = worldGui
	Skin.scenery(world)

	-- O tabuleiro mora na camada do cenário (sem área segura): assim a arte do mapa sangra por
	-- baixo da barra do Roblox e o HUD, que respeita a área segura, flutua por cima dela.
	local boardHost = currentScope:New("Frame")({
		Name = "BoardHost",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		Visible = Bridge.use(currentScope, Atoms.inMatch),
		ZIndex = 2,
	})
	boardHost.Parent = worldGui
	opts.onBoardArea(boardHost)

	-- elapsed alimenta as telas que precisam falar sobre demora (entrada e carregamento)
	local elapsed = currentScope:Value(0)

	local inMatch = Bridge.use(currentScope, Atoms.inMatch)
	scaledContent(currentScope, hudGui, {
		Hud(currentScope, {
			visible = inMatch,
			localUserId = opts.localUserId,
		}),
	})

	scaledContent(currentScope, menuGui, {
		Boot(currentScope, { visible = routeIs(currentScope, "boot"), elapsed = elapsed }),
		MainMenu(currentScope, { visible = routeIs(currentScope, "menu") }),
		Maps(currentScope, { visible = routeIs(currentScope, "maps") }),
		Rooms(currentScope, { visible = routeIs(currentScope, "rooms") }),
		Party(currentScope, { visible = routeIs(currentScope, "party") }),
		Invites(currentScope, { visible = routeIs(currentScope, "invites") }),
		Collection(currentScope, { visible = routeIs(currentScope, "collection") }),
		Cosmetics(currentScope, { visible = routeIs(currentScope, "cosmetics") }),
		Shop(currentScope, { visible = routeIs(currentScope, "shop") }),
		Settings(currentScope, { visible = routeIs(currentScope, "settings") }),
		Loading(currentScope, { visible = routeIs(currentScope, "loading"), elapsed = elapsed }),
	})

	local matchResult = Bridge.use(currentScope, Atoms.matchResult)
	scaledContent(currentScope, modalGui, {
		Result(currentScope, {
			visible = currentScope:Computed(function(use)
				return use(matchResult) ~= nil
			end),
		}),
		ModalHost(currentScope),
		Orientation(currentScope),
	})

	local toastContent = currentScope:New("Frame")({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false, -- aviso curto nunca recebe toque
		[Children] = Kit.children(Toasts(currentScope), InviteCards(currentScope)),
	})
	toastContent.Parent = toastGui

	-- Um laço só para a interface inteira: convites, avisos, conexão e contadores de espera.
	if not ticking then
		ticking = true
		local accumulator = 0
		local waitingSince = os.clock()
		local lastRoute: Atoms.Route = Atoms.route() :: Atoms.Route
		RunService.Heartbeat:Connect(function(deltaTime: number)
			accumulator += deltaTime
			if accumulator < 0.1 then
				return
			end
			accumulator = 0
			local now = os.clock()
			local route: Atoms.Route = Atoms.route() :: Atoms.Route
			if route ~= lastRoute then
				lastRoute = route
				waitingSince = now
			end
			Actions.expireInvites(now)
			-- aviso de orientação: celular em retrato (o combate continua rodando no servidor)
			Atoms.orientationWarning(InputController.isPortrait() and InputController.isTouchDevice())
			Actions.expireToasts(now)
			Actions.expireAnnounce(now)
			if Atoms.inMatch() then
				Actions.updateConnection(now)
			end
			if route == "boot" or route == "loading" then
				elapsed:set(now - waitingSince)
			end
		end)
	end
end

function App.init(opts: Options)
	options = opts
	Responsive.init()
	Accessibility.init()
	Atoms.compact(Responsive.isCompact())
	Responsive.onChange(function(_, modeChanged)
		Atoms.compact(Responsive.isCompact())
		if modeChanged then
			App.mount()
		else
			-- só a escala mudou: reaproveita a árvore montada
			local currentScope = scope
			if not currentScope then
				return
			end
			for _, gui in ipairs(opts.playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Name:sub(1, 7) == "Quintal" then
					local content = gui:FindFirstChild("Content")
					local uiScale = content and content:FindFirstChildOfClass("UIScale")
					if content and uiScale and content:IsA("GuiObject") then
						local state = Responsive.get()
						uiScale.Scale = state.scale
						content.Size = UDim2.fromScale(1 / state.scale, 1 / state.scale)
					end
				end
			end
		end
	end)
	App.mount()
end

return App
