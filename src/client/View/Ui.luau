--!strict
-- Construtores de interface: painéis, botões acessíveis (mín. 44 px), rótulos e diálogos de confirmação.
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

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

local kindStyles: { [string]: { bg: Color3, fg: Color3, stroke: Color3 } } = {
	primary = { bg = Theme.colors.gold, fg = Theme.colors.ink, stroke = Theme.colors.ink },
	secondary = { bg = Theme.colors.cream, fg = Theme.colors.ink, stroke = Theme.colors.ink },
	danger = { bg = Theme.colors.dangerSoft, fg = Theme.colors.danger, stroke = Theme.colors.danger },
	ghost = { bg = Theme.colors.paper, fg = Theme.colors.muted, stroke = Theme.colors.muted },
	dark = { bg = Theme.colors.ink, fg = Theme.colors.cream, stroke = Theme.colors.ink },
	cyan = { bg = Theme.colors.cyan, fg = Theme.colors.ink, stroke = Theme.colors.ink },
}

export type Button = {
	instance: TextButton,
	label: TextLabel,
	sub: TextLabel,
	setEnabled: (self: Button, enabled: boolean, reason: string?) -> (),
	setText: (self: Button, text: string, sub: string?) -> (),
	setKind: (self: Button, kind: ButtonKind) -> (),
	onClick: (self: Button, fn: () -> ()) -> RBXScriptConnection,
	destroy: (self: Button) -> (),
}

local reducedMotion = false
function Ui.setReducedMotion(value: boolean)
	reducedMotion = value
end
function Ui.isReducedMotion(): boolean
	return reducedMotion
end

function Ui.button(parent: Instance?, name: string, text: string, kind: ButtonKind?, props: { [string]: any }?): Button
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.Size = UDim2.new(0, 160, 0, Theme.sizes.buttonTarget)
	b.Font = Theme.fonts.bodyBold
	if props then
		for k, v in pairs(props) do
			(b :: any)[k] = v
		end
	end
	Ui.corner(b)
	local stroke = Ui.stroke(b)
	local label = Ui.label(b, "Label", text, {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		Font = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.bodyLarge,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local sub = Ui.label(b, "Sub", "", {
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.new(0, 8, 1, -18),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(Theme.sizes.buttonMin, Theme.sizes.buttonMin)
	minSize.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local currentKind: ButtonKind = kind or "secondary"
	local enabled = true

	local self = {} :: Button
	self.instance = b
	self.label = label
	self.sub = sub
	local function applyStyle()
		local style = kindStyles[currentKind]
		b.BackgroundColor3 = style.bg
		label.TextColor3 = style.fg
		sub.TextColor3 = style.fg
		stroke.Color = style.stroke
		if not enabled then
			b.BackgroundColor3 = Theme.colors.creamDark
			label.TextColor3 = Theme.colors.muted
			sub.TextColor3 = Theme.colors.muted
			stroke.Color = Theme.colors.muted
		end
	end
	function self.setKind(_, newKind: ButtonKind)
		currentKind = newKind
		applyStyle()
	end
	function self.setEnabled(_, value: boolean, reason: string?)
		enabled = value
		b.Active = true -- continua clicável para explicar o motivo
		if reason and reason ~= "" then
			sub.Text = reason
			sub.Visible = true
			label.Position = UDim2.new(0, 8, 0, -6)
		elseif reason == "" or not value then
			sub.Text = ""
			sub.Visible = false
			label.Position = UDim2.new(0, 8, 0, 0)
		else
			sub.Visible = sub.Text ~= ""
			label.Position = if sub.Visible then UDim2.new(0, 8, 0, -6) else UDim2.new(0, 8, 0, 0)
		end
		applyStyle()
	end
	function self.setText(_, newText: string, newSub: string?)
		label.Text = newText
		if newSub ~= nil then
			sub.Text = newSub
			sub.Visible = newSub ~= ""
			label.Position = if sub.Visible then UDim2.new(0, 8, 0, -6) else UDim2.new(0, 8, 0, 0)
		end
	end
	function self.onClick(_, fn: () -> ()): RBXScriptConnection
		return b.Activated:Connect(function()
			if not reducedMotion then
				scale.Scale = 0.96
				TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1 }):Play()
			end
			if enabled then
				fn()
			end
		end)
	end
	function self.destroy(_)
		b:Destroy()
	end
	b.MouseEnter:Connect(function()
		if not reducedMotion then
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.03 }):Play()
		end
		stroke.Thickness = 3
	end)
	b.MouseLeave:Connect(function()
		if not reducedMotion then
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
		end
		stroke.Thickness = Theme.sizes.stroke
	end)
	b.SelectionGained:Connect(function()
		stroke.Thickness = 3
	end)
	b.SelectionLost:Connect(function()
		stroke.Thickness = Theme.sizes.stroke
	end)
	applyStyle()
	b.Parent = parent
	return self
end

-- Diálogo modal de confirmação. onConfirm/onCancel opcionais.
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
	local overlay = Ui.frame(parent, "ConfirmOverlay", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.45,
		ZIndex = 50,
	})
	overlay.Active = true
	local box = Ui.panel(overlay, "Box", {
		Size = UDim2.new(0, 420, 0, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 51,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(420, 260)
	constraint.Parent = box
	box.Size = UDim2.new(0.9, 0, 0, 200)
	Ui.padding(box, 16)
	Ui.title(box, "Title", titleText, { Size = UDim2.new(1, 0, 0, 34), TextSize = 24, ZIndex = 52 })
	Ui.label(box, "Body", bodyText, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0, 40), ZIndex = 52 })
	local row = Ui.frame(
		box,
		"Row",
		{ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48), BackgroundTransparency = 1, ZIndex = 52 }
	)
	Ui.list(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right)
	local cancel = Ui.button(
		row,
		"Cancel",
		cancelText,
		"secondary",
		{ Size = UDim2.new(0, 150, 0, 48), ZIndex = 53, LayoutOrder = 1 }
	)
	local ok = Ui.button(
		row,
		"Confirm",
		confirmText,
		if danger then "danger" else "primary",
		{ Size = UDim2.new(0, 180, 0, 48), ZIndex = 53, LayoutOrder = 2 }
	)
	cancel:onClick(function()
		overlay:Destroy()
		if onCancel then
			onCancel()
		end
	end)
	ok:onClick(function()
		overlay:Destroy()
		onConfirm()
	end)
	return overlay
end

-- Aviso curto (toast) no topo.
function Ui.toast(parent: Instance, text: string, danger: boolean?)
	local existing = parent:FindFirstChild("Toast")
	if existing then
		existing:Destroy()
	end
	local t = Ui.canvasPanel(parent, "Toast", {
		Size = UDim2.new(0, 10, 0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 0, 72),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = if danger then Theme.colors.dangerSoft else Theme.colors.cream,
		ZIndex = 60,
	})
	Ui.padding(t, 14, 8)
	Ui.label(t, "Text", (if danger then "⚠ " else "") .. text, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = if danger then Theme.colors.danger else Theme.colors.ink,
		Font = Theme.fonts.bodyMedium,
		ZIndex = 61,
	})
	if not reducedMotion then
		t.GroupTransparency = 1
		t.Position = UDim2.new(0.5, 0, 0, 60)
		TweenService:Create(
			t,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 72) }
		):Play()
	end
	task.delay(2.6, function()
		if not t.Parent then
			return
		end
		if reducedMotion then
			t:Destroy()
			return
		end
		local out = TweenService:Create(t, TweenInfo.new(0.2), { GroupTransparency = 1 })
		out:Play()
		out.Completed:Once(function()
			if t.Parent then
				t:Destroy()
			end
		end)
	end)
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
