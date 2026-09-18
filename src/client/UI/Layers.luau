--!strict
-- Camadas de renderização da interface (guia, "Camadas de renderização").
--
--   world  DisplayOrder  0  fundo e decoração, sem nenhuma área clicável
--   hud    DisplayOrder 10  tabuleiro e HUD de combate
--   menu   DisplayOrder 20  telas de menu (entrada, mapas, coleção, opções…)
--   modal  DisplayOrder 30  modais bloqueadores e resultado
--   toast  DisplayOrder 40  avisos curtos, nunca modais
--
-- Esses valores são decisões locais e não substituem a CoreGui. A ScreenGui decorativa fica
-- separada das interativas: só as interativas usam ScreenInsets = CoreUISafeInsets, e a
-- transformação do tabuleiro não soma GetGuiInset de novo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTokens = require(ReplicatedStorage.Shared.Config.UiTokens)
local Theme = require(script.Parent.Parent.View.Theme)
local Responsive = require(script.Parent.Parent.View.Responsive)
local Components = require(script.Parent.Components)

local Layers = {}

export type Layer = { gui: ScreenGui, content: Frame, scale: UIScale? }

local layers: { [string]: Layer } = {}

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
	if interactive then
		-- área segura real (notch, barra do sistema): os controles ficam dentro dela
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	else
		gui.ScreenInsets = Enum.ScreenInsets.None
	end
	gui.Parent = playerGui
	return gui
end

-- O conteúdo escalado vive dentro de um Frame de tamanho inverso, para que o layout continue
-- sendo escrito na resolução de referência enquanto a janela cresce.
local function makeContent(gui: ScreenGui, scaled: boolean): (Frame, UIScale?)
	local content = Components.frame(gui, "Content", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	if not scaled then
		return content, nil
	end
	local scale = Instance.new("UIScale")
	scale.Parent = content
	return content, scale
end

function Layers.init(playerGui: PlayerGui)
	local order = UiTokens.displayOrder

	local worldGui = makeGui(playerGui, "QuintalWorld", order.world, false)
	local worldContent = Components.frame(worldGui, "Content", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
	})
	worldContent.Active = false
	layers.world = { gui = worldGui, content = worldContent }

	local hudGui = makeGui(playerGui, "QuintalHud", order.hud, true)
	local hudContent, hudScale = makeContent(hudGui, true)
	layers.hud = { gui = hudGui, content = hudContent, scale = hudScale }

	local menuGui = makeGui(playerGui, "QuintalMenu", order.menu, true)
	local menuContent, menuScale = makeContent(menuGui, true)
	layers.menu = { gui = menuGui, content = menuContent, scale = menuScale }

	local modalGui = makeGui(playerGui, "QuintalModal", order.modal, true)
	local modalContent, modalScale = makeContent(modalGui, true)
	modalContent.Visible = true
	layers.modal = { gui = modalGui, content = modalContent, scale = modalScale }

	local toastGui = makeGui(playerGui, "QuintalToast", order.toast, true)
	local toastContent = Components.frame(toastGui, "Content", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	toastContent.Active = false -- toast não é modal e não recebe toque
	layers.toast = { gui = toastGui, content = toastContent }

	Layers.applyScale()
	Responsive.onChange(function()
		Layers.applyScale()
	end)
end

function Layers.applyScale()
	local state = Responsive.get()
	for _, layer in pairs(layers) do
		if layer.scale then
			(layer.scale :: UIScale).Scale = state.scale
			layer.content.Size = UDim2.fromScale(1 / state.scale, 1 / state.scale)
		end
	end
end

function Layers.get(name: string): Layer
	local layer = layers[name]
	assert(layer, `camada desconhecida: {name}`)
	return layer
end

function Layers.content(name: string): Frame
	return Layers.get(name).content
end

-- Bloqueia a entrada nas camadas de baixo enquanto existe um modal aberto.
function Layers.setModalBlocking(blocking: boolean)
	layers.modal.content.Active = blocking
end

return Layers
