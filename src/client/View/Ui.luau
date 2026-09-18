--!strict
-- Construtores de interface usados pelo combate (painéis, rótulos e formatação de números).
--
-- Botão, confirmação e aviso curto são adaptadores finos sobre a biblioteca nova em UI/:
-- Components.button (oito estados + foco), Modal (família da prancha 38) e Toasts (fila de 3).
-- Assim o HUD antigo e as telas novas compartilham o mesmo contrato de interação.
local Theme = require(script.Parent.Theme)
local Accessibility = require(script.Parent.Parent.UI.Accessibility)
local Components = require(script.Parent.Parent.UI.Components)
local Focus = require(script.Parent.Parent.UI.Focus)
local Modal = require(script.Parent.Parent.UI.Modal)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local Ui = {}

export type ButtonKind = "primary" | "secondary" | "danger" | "ghost" | "dark" | "cyan"

function Ui.corner(parent: GuiObject, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.sizes.corner)
	c.Parent = parent
	return c
end

function Ui.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.colors.ink
	s.Thickness = thickness or Theme.sizes.stroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Ui.padding(parent: GuiObject, all: number, vertical: number?): UIPadding
	local p = Instance.new("UIPadding")
	local v = vertical or all
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.PaddingTop = UDim.new(0, v)
	p.PaddingBottom = UDim.new(0, v)
	p.Parent = parent
	return p
end

function Ui.list(
	parent: GuiObject,
	direction: Enum.FillDirection,
	gap: number,
	align: Enum.HorizontalAlignment?
): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

function Ui.frame(parent: Instance?, name: string, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Theme.colors.cream
	f.BorderSizePixel = 0
	if props then
		for k, v in pairs(props) do
			(f :: any)[k] = v
		end
	end
	f.Parent = parent
	return f
end

function Ui.panel(parent: Instance?, name: string, props: { [string]: any }?): Frame
	local f = Ui.frame(parent, name, props)
	Ui.corner(f)
	Ui.stroke(f)
	return f
end

-- Painel que pode esmaecer como um todo (CanvasGroup). Use para painéis pequenos e médios.
function Ui.canvasPanel(parent: Instance?, name: string, props: { [string]: any }?): CanvasGroup
	local g = Instance.new("CanvasGroup")
	g.Name = name
	g.BackgroundColor3 = Theme.colors.cream
	g.BorderSizePixel = 0
	if props then
		for k, v in pairs(props) do
			(g :: any)[k] = v
		end
	end
	Ui.corner(g)
	Ui.stroke(g)
	g.Parent = parent
	return g
end

function Ui.label(parent: Instance?, name: string, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Theme.fonts.body
	l.TextColor3 = Theme.colors.ink
	l.TextSize = Theme.sizes.body
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.BorderSizePixel = 0
	if props then
		for k, v in pairs(props) do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

function Ui.title(parent: Instance?, name: string, text: string, props: { [string]: any }?): TextLabel
	local l = Ui.label(parent, name, text, props)
	l.Font = Theme.fonts.title
	l.TextSize = Theme.sizes.title
	if props and props.TextSize then
		l.TextSize = props.TextSize
	end
	return l
end

export type Button = Components.Button

-- Preferência efetiva de movimento reduzido (Roblox + opção do jogo), para o Motion legado.
function Ui.setReducedMotion(_: boolean)
	-- mantido por compatibilidade: a fonte de verdade agora é UI/Accessibility
end

function Ui.isReducedMotion(): boolean
	return Accessibility.reducedMotion()
end

-- Adaptador: mantém a assinatura antiga do HUD e devolve o componente completo da prancha 37
-- (que já expõe setEnabled/onClick como apelidos de setAvailable/onActivate).
function Ui.button(parent: Instance?, name: string, text: string, kind: ButtonKind?, props: { [string]: any }?): Button
	local options: Components.ButtonOptions = { name = name, text = text, kind = kind }
	if props then
		options.size = props.Size
		options.position = props.Position
		options.anchorPoint = props.AnchorPoint
		options.layoutOrder = props.LayoutOrder
		options.zIndex = props.ZIndex
		options.visible = props.Visible
	end
	local button = Components.button(parent, options)
	if props then
		for key, value in pairs(props) do
			if
				key ~= "Size"
				and key ~= "Position"
				and key ~= "AnchorPoint"
				and key ~= "LayoutOrder"
				and key ~= "ZIndex"
				and key ~= "Visible"
			then
				(button.instance :: any)[key] = value
			end
		end
	end
	return button
end

-- Confirmação: usa a família compartilhada de modais (scrim, foco inicial no cancelamento,
-- retorno de foco ao fechar e botão principal nomeando a ação).
function Ui.confirm(
	parent: Instance,
	titleText: string,
	bodyText: string,
	confirmText: string,
	cancelText: string,
	danger: boolean,
	onConfirm: () -> (),
	onCancel: (() -> ())?
)
	return Modal.open(parent, {
		title = titleText,
		body = bodyText,
		confirmText = confirmText,
		cancelText = cancelText,
		danger = danger,
		opener = Focus.current(),
		onConfirm = function(controls)
			controls:close()
			onConfirm()
		end,
		onCancel = onCancel,
	})
end

-- Aviso curto: entra na fila global (máximo três, deduplicada por 1 s).
function Ui.toast(_: Instance, text: string, danger: boolean?)
	Toasts.show(text, if danger then "error" else "info")
end

local ACCENT_UPPER: { [string]: string } = {
	["á"] = "Á",
	["à"] = "À",
	["â"] = "Â",
	["ã"] = "Ã",
	["é"] = "É",
	["ê"] = "Ê",
	["í"] = "Í",
	["ó"] = "Ó",
	["ô"] = "Ô",
	["õ"] = "Õ",
	["ú"] = "Ú",
	["ç"] = "Ç",
}

-- Maiúsculas preservando acentos do português (string.upper só trata ASCII)
function Ui.upper(text: string): string
	local out = string.upper(text)
	for lower, upperChar in pairs(ACCENT_UPPER) do
		out = out:gsub(lower, upperChar)
	end
	return out
end

function Ui.formatNumber(n: number): string
	local rounded = math.floor(n + 0.5)
	local s = tostring(rounded)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Ui.formatDecimal(n: number, places: number?): string
	local p = places or 1
	local s = string.format("%." .. p .. "f", n)
	s = s:gsub("%.?0+$", "")
	return (s:gsub("%.", ","))
end

return Ui
