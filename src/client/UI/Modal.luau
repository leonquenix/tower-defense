--!strict
-- Família compartilhada de modais (prancha 38): venda, Pulso, saída, desbloqueio,
-- especialização, substituição de slot, limpeza do treino e tutorial repetido.
--
-- Regras do guia aplicadas aqui:
--  * margens, scrim e entrada iguais em todas as variantes (modal_enter: scrim 45%, painel 0,96→1);
--  * foco inicial no cancelamento; ao fechar, o foco volta ao botão que abriu, se ainda existir;
--  * o botão principal nomeia a ação ("Vender", "Escolher Rajada") — nunca um "Sim" genérico;
--  * abrir um modal não envia comando; durante o pendente o modal continua aberto;
--  * o scrim intercepta o toque: nada atravessa para o tabuleiro.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Theme = require(script.Parent.Parent.View.Theme)
local Accessibility = require(script.Parent.Accessibility)
local Anim = require(script.Parent.Anim)
local Components = require(script.Parent.Components)
local Focus = require(script.Parent.Focus)

local Modal = {}

local L = Localization.get

export type Controls = {
	setPending: (self: Controls, pending: boolean) -> (),
	setError: (self: Controls, text: string?) -> (),
	setBody: (self: Controls, text: string) -> (),
	close: (self: Controls) -> (),
	content: Frame,
}

export type Options = {
	title: string,
	body: string,
	confirmText: string,
	cancelText: string?,
	danger: boolean?,
	-- Modais informativos (tutorial repetido) dispensam Cancelar: só "Continuar" basta.
	hideCancel: boolean?,
	opener: GuiButton?,
	width: number?,
	build: ((content: Frame, controls: Controls) -> ())?,
	onConfirm: (controls: Controls) -> (),
	onCancel: (() -> ())?,
}

local sequence = 0
local openCount = 0
local host: Instance? = nil

-- Camada ModalGui (DisplayOrder 30). Definida uma vez no boot; as telas continuam chamando
-- Modal.open com o próprio root, mas o modal sobe para a camada certa.
function Modal.setHost(frame: Instance)
	host = frame
end

function Modal.isOpen(): boolean
	return openCount > 0
end

function Modal.open(parent: Instance, options: Options): Controls
	sequence += 1
	openCount += 1
	local scope = "modal:" .. sequence
	local target: Instance = host or parent

	local overlay = Components.frame(target, "Modal_" .. sequence, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 1,
		ZIndex = 1,
	})
	overlay.Active = true -- scrim: consome o toque, nada passa para o mundo

	local width = options.width or 480
	local box = Components.panel(overlay, "Box", {
		Size = UDim2.new(0, width, 0, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, { tape = true, shadow = false })
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(width, 560)
	sizeConstraint.MinSize = Vector2.new(280, 0)
	sizeConstraint.Parent = box
	Components.padding(box, 20, 18)
	local boxLayout = Components.list(box, Enum.FillDirection.Vertical, 12)
	boxLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	boxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local scale = Instance.new("UIScale")
	scale.Parent = box

	Components.title(box, "Title", options.title, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 24,
		LayoutOrder = 1,
		ZIndex = 3,
	})
	local bodyLabel = Components.label(box, "Body", options.body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		ZIndex = 3,
	})
	-- área opcional para comparação de atributos, lista de slots, preço projetado…
	local content = Components.frame(box, "Content", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 3,
	})
	local contentLayout = Components.list(content, Enum.FillDirection.Vertical, 8)
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	local errorLabel = Components.label(box, "Error", "", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = Theme.colors.danger,
		Font = Theme.fonts.bodyMedium,
		TextSize = Theme.sizes.caption,
		Visible = false,
		LayoutOrder = 4,
		ZIndex = 3,
	})

	local row = Components.frame(box, "Actions", {
		Size = UDim2.new(1, 0, 0, Theme.sizes.buttonTarget + 4),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		ZIndex = 3,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)

	local closed = false
	local pending = false
	local cancelButton: Components.Button? = nil
	local confirmButton: Components.Button

	local controls = {} :: Controls
	controls.content = content

	local function finish(runCancel: boolean)
		if closed then
			return
		end
		closed = true
		openCount -= 1
		Focus.popScope(scope)
		if cancelButton then
			cancelButton:destroy()
		end
		confirmButton:destroy()
		Anim.cancelAll(scale)
		Anim.cancelAll(overlay)
		overlay:Destroy()
		if runCancel and options.onCancel then
			options.onCancel()
		end
	end

	function controls.setPending(_, value: boolean)
		pending = value
		confirmButton:setPending(value)
		-- Cancelar continua disponível: fechar a tela não desfaz o que o servidor já aceitou,
		-- e o jogador precisa poder sair de um pedido travado.
		if cancelButton then
			cancelButton:setAvailable(true)
		end
	end

	function controls.setError(_, text: string?)
		pending = false
		confirmButton:setPending(false)
		errorLabel.Text = text or ""
		errorLabel.Visible = (text or "") ~= ""
	end

	function controls.setBody(_, text: string)
		bodyLabel.Text = text
	end

	function controls.close(_)
		finish(false)
	end

	if not options.hideCancel then
		cancelButton = Components.button(row, {
			name = "Cancel",
			text = options.cancelText or L("common.cancel"),
			kind = "secondary",
			size = UDim2.fromOffset(160, Theme.sizes.buttonTarget),
			layoutOrder = 1,
			zIndex = 4,
			focusScope = scope,
			onActivate = function()
				finish(true) -- cancelar nunca manda comando
			end,
		})
	end
	confirmButton = Components.button(row, {
		name = "Confirm",
		text = options.confirmText,
		kind = if options.danger then "danger" else "primary",
		size = UDim2.fromOffset(200, Theme.sizes.buttonTarget),
		layoutOrder = 2,
		zIndex = 4,
		focusScope = scope,
		onActivate = function()
			if pending then
				return
			end
			errorLabel.Visible = false
			options.onConfirm(controls)
		end,
	})

	Focus.pushScope(scope, options.opener, function()
		finish(true)
	end)
	if options.build then
		options.build(content, controls)
	end
	-- foco inicial no cancelamento (ou na única ação, quando não há cancelamento)
	Focus.set(if cancelButton then cancelButton.instance else confirmButton.instance)

	if Accessibility.reducedMotion() then
		overlay.BackgroundTransparency = 0.45
	else
		scale.Scale = 0.96
		Anim.play(overlay, "modal_enter", { BackgroundTransparency = 0.45 })
		Anim.play(scale, "modal_enter", { Scale = 1 })
	end

	return controls
end

return Modal
