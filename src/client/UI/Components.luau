--!strict
-- Biblioteca de componentes nativos (prancha 37 e "Biblioteca nativa" do guia).
--
-- Tudo aqui é Frame/TextButton/TextLabel/ImageLabel com UICorner, UIStroke, UIScale e layouts:
-- nenhuma prancha é usada como imagem de tela. Texto, preço, motivo e barra são elementos vivos.
--
-- Estados do ActionButton: idle, hover, focus, pressed, selected, disabled, pending, success, error.
-- Só GuiButton.Activated confirma clique/toque (nada em InputEnded).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local UiIcons = require(ReplicatedStorage.Shared.Config.UiIcons)
local Theme = require(script.Parent.Parent.View.Theme)
local Accessibility = require(script.Parent.Accessibility)
local Anim = require(script.Parent.Anim)
local Focus = require(script.Parent.Focus)

local Components = {}

local L = Localization.get

export type ButtonKind = "primary" | "secondary" | "danger" | "ghost" | "dark" | "cyan" | "quiet"

type KindStyle = { bg: Color3, fg: Color3, stroke: Color3 }

local KINDS: { [string]: KindStyle } = {
	primary = { bg = Theme.colors.gold, fg = Theme.colors.ink, stroke = Theme.colors.ink },
	secondary = { bg = Theme.colors.surface, fg = Theme.colors.ink, stroke = Theme.colors.ink },
	danger = { bg = Theme.colors.dangerSoft, fg = Theme.colors.danger, stroke = Theme.colors.danger },
	ghost = { bg = Theme.colors.surface, fg = Theme.colors.muted, stroke = Theme.colors.muted },
	dark = { bg = Theme.colors.ink, fg = Theme.colors.cream, stroke = Theme.colors.ink },
	cyan = { bg = Theme.colors.cyan, fg = Theme.colors.ink, stroke = Theme.colors.ink },
	quiet = { bg = Theme.colors.sage, fg = Theme.colors.ink, stroke = Theme.colors.muted },
}

local DISABLED: KindStyle = { bg = Theme.colors.sage, fg = Theme.colors.muted, stroke = Theme.colors.muted }
local PENDING: KindStyle = { bg = Theme.colors.sage, fg = Theme.colors.muted, stroke = Theme.colors.muted }
local SUCCESS: KindStyle = { bg = Theme.colors.gold, fg = Theme.colors.ink, stroke = Theme.colors.ink }
local ERROR: KindStyle = { bg = Theme.colors.surface, fg = Theme.colors.danger, stroke = Theme.colors.danger }

local SUCCESS_HOLD = 2.5 -- o selo de sucesso some sozinho; o erro fica até a próxima ação

-- ---------------------------------------------------------------------------
-- Primitivos
-- ---------------------------------------------------------------------------

function Components.corner(parent: GuiObject, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.sizes.corner)
	corner.Parent = parent
	return corner
end

function Components.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.colors.ink
	stroke.Thickness = thickness or Theme.sizes.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Components.padding(parent: GuiObject, horizontal: number, vertical: number?): UIPadding
	local padding = Instance.new("UIPadding")
	local v = vertical or horizontal
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.PaddingTop = UDim.new(0, v)
	padding.PaddingBottom = UDim.new(0, v)
	padding.Parent = parent
	return padding
end

function Components.list(
	parent: GuiObject,
	direction: Enum.FillDirection,
	gap: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = vertical or Enum.VerticalAlignment.Center
	layout.Parent = parent
	return layout
end

function Components.frame(parent: Instance?, name: string, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.colors.surface
	frame.BorderSizePixel = 0
	if props then
		for key, value in pairs(props) do
			(frame :: any)[key] = value
		end
	end
	frame.Parent = parent
	return frame
end

function Components.label(parent: Instance?, name: string, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Theme.fonts.body
	label.TextColor3 = Theme.colors.ink
	label.TextSize = Accessibility.scaleText(Theme.sizes.body)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	if props then
		for key, value in pairs(props) do
			(label :: any)[key] = value
		end
	end
	-- a preferência de texto ampliado do Roblox multiplica o tamanho de referência
	if not (props and props.TextScaled) then
		label.TextSize = Accessibility.scaleText(label.TextSize)
	end
	label.Parent = parent
	return label
end

function Components.title(parent: Instance?, name: string, text: string, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = { Font = Theme.fonts.title, TextSize = Theme.sizes.title }
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end
	return Components.label(parent, name, text, merged)
end

function Components.caption(parent: Instance?, name: string, text: string, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		TextSize = Theme.sizes.caption,
		TextColor3 = Theme.colors.muted,
		Font = Theme.fonts.bodyMedium,
	}
	if props then
		for key, value in pairs(props) do
			merged[key] = value
		end
	end
	return Components.label(parent, name, text, merged)
end

-- Rolagem com conteúdo automático; usada sempre que o texto pode crescer (idioma, texto ampliado).
function Components.scroller(parent: Instance?, name: string, props: { [string]: any }?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.colors.muted
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	if props then
		for key, value in pairs(props) do
			(scroll :: any)[key] = value
		end
	end
	scroll.Parent = parent
	return scroll
end

-- ---------------------------------------------------------------------------
-- PaperPanel: ficha de papel creme com contorno ink, sombra curta e fita dourada
-- ---------------------------------------------------------------------------

export type PanelOptions = {
	tape: boolean?, -- fita dourada decorativa no topo (não interativa)
	shadow: boolean?,
	radius: number?,
	color: Color3?,
	strokeColor: Color3?,
}

function Components.panel(parent: Instance?, name: string, props: { [string]: any }?, options: PanelOptions?): Frame
	local opts: PanelOptions = options or {}
	local panel = Components.frame(parent, name, props)
	panel.BackgroundColor3 = opts.color or Theme.colors.surface
	Components.corner(panel, opts.radius or Theme.sizes.panelCorner)
	Components.stroke(panel, opts.strokeColor)
	if opts.shadow ~= false then
		local shadow = Components.frame(nil, "Shadow", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 4),
			BackgroundColor3 = Theme.colors.ink,
			BackgroundTransparency = 0.88,
			ZIndex = math.max(panel.ZIndex - 1, 0),
			Active = false,
		})
		Components.corner(shadow, opts.radius or Theme.sizes.panelCorner)
		shadow.Parent = panel.Parent
		shadow.Position = panel.Position + UDim2.fromOffset(0, 4)
		shadow.Size = panel.Size
		shadow.AnchorPoint = panel.AnchorPoint
		shadow.Name = name .. "Shadow"
		-- a sombra acompanha o painel quando o layout muda
		panel:GetPropertyChangedSignal("Position"):Connect(function()
			shadow.Position = panel.Position + UDim2.fromOffset(0, 4)
		end)
		panel:GetPropertyChangedSignal("Size"):Connect(function()
			shadow.Size = panel.Size
		end)
		panel.Destroying:Connect(function()
			shadow:Destroy()
		end)
	end
	if opts.tape then
		local tape = Components.frame(panel, "Tape", {
			Size = UDim2.fromOffset(34, 10),
			Position = UDim2.fromOffset(18, -5),
			BackgroundColor3 = Theme.colors.gold,
			ZIndex = panel.ZIndex + 1,
			Active = false,
		})
		Components.corner(tape, 5)
	end
	return panel
end

-- ---------------------------------------------------------------------------
-- Ícone: ImageLabel quando publicado, glifo nativo enquanto o upload não acontece
-- ---------------------------------------------------------------------------

export type IconHandle = { instance: GuiObject, setColor: (self: IconHandle, color: Color3) -> () }

function Components.icon(parent: Instance?, key: string, size: number, props: { [string]: any }?): IconHandle?
	local def = UiIcons[key]
	if not def then
		return nil
	end
	local common: { [string]: any } = {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Active = false,
	}
	if props then
		for k, value in pairs(props) do
			common[k] = value
		end
	end
	if def.image then
		local image = Instance.new("ImageLabel")
		image.Name = key
		image.Image = def.image :: string
		image.ScaleType = Enum.ScaleType.Fit
		image.ImageColor3 = Theme.colors.ink
		for k, value in pairs(common) do
			(image :: any)[k] = value
		end
		image.Parent = parent
		local handle: IconHandle = {
			instance = image,
			setColor = function(_, color: Color3)
				image.ImageColor3 = color
			end,
		}
		return handle
	end
	local glyph = Components.label(parent, key, def.glyph, {
		Size = common.Size,
		Position = common.Position,
		AnchorPoint = common.AnchorPoint,
		LayoutOrder = common.LayoutOrder,
		ZIndex = common.ZIndex,
		TextSize = math.floor(size * 0.9),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		Font = Theme.fonts.bodyBold,
	})
	local handle: IconHandle = {
		instance = glyph,
		setColor = function(_, color: Color3)
			glyph.TextColor3 = color
		end,
	}
	return handle
end

-- ---------------------------------------------------------------------------
-- ActionButton
-- ---------------------------------------------------------------------------

export type ButtonOptions = {
	name: string,
	text: string,
	sub: string?,
	kind: ButtonKind?,
	icon: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	textSize: number?,
	textAlign: Enum.TextXAlignment?,
	-- motivo de bloqueio substitui o rótulo em vez de ir para a segunda linha (pranchas 15 e 37)
	reasonAsLabel: boolean?,
	visible: boolean?,
	focusScope: string?,
	onActivate: (() -> ())?,
}

export type Button = {
	instance: TextButton,
	label: TextLabel,
	sub: TextLabel,
	setText: (self: Button, text: string, sub: string?) -> (),
	setKind: (self: Button, kind: ButtonKind) -> (),
	setAvailable: (self: Button, available: boolean, reason: string?) -> (),
	setSelected: (self: Button, selected: boolean) -> (),
	setPending: (self: Button, pending: boolean, text: string?) -> (),
	flashSuccess: (self: Button, text: string?) -> (),
	showError: (self: Button, text: string?) -> (),
	clearResult: (self: Button) -> (),
	isAvailable: (self: Button) -> boolean,
	onActivate: (self: Button, fn: () -> ()) -> (),
	destroy: (self: Button) -> (),
}

function Components.button(parent: Instance?, options: ButtonOptions): Button
	local button = Instance.new("TextButton")
	button.Name = options.name
	button.AutoButtonColor = false -- a aparência é controlada pelo componente
	button.Text = ""
	button.BorderSizePixel = 0
	button.Size = options.size or UDim2.fromOffset(180, Theme.sizes.buttonTarget)
	button.Position = options.position or UDim2.fromOffset(0, 0)
	button.AnchorPoint = options.anchorPoint or Vector2.zero
	button.LayoutOrder = options.layoutOrder or 0
	button.ZIndex = options.zIndex or 1
	button.Visible = if options.visible == nil then true else options.visible
	button.Selectable = true
	Components.corner(button)
	local stroke = Components.stroke(button)

	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(Theme.sizes.buttonMin, Theme.sizes.buttonMin)
	minSize.Parent = button

	local scale = Instance.new("UIScale")
	scale.Name = "InteractionScale"
	scale.Parent = button

	local iconHandle: IconHandle? = nil
	local textLeft = 10
	if options.icon then
		iconHandle = Components.icon(button, options.icon, 22, {
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = button.ZIndex + 1,
		})
		if iconHandle then
			textLeft = 40
		end
	end

	local label = Components.label(button, "Label", options.text, {
		Size = UDim2.new(1, -(textLeft + 10), 1, 0),
		Position = UDim2.new(0, textLeft, 0, 0),
		Font = Theme.fonts.bodyBold,
		TextSize = options.textSize or Theme.sizes.button,
		TextXAlignment = options.textAlign or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = button.ZIndex + 1,
	})
	local sub = Components.caption(button, "Sub", options.sub or "", {
		Size = UDim2.new(1, -(textLeft + 10), 0, 15),
		Position = UDim2.new(0, textLeft, 1, -17),
		TextXAlignment = options.textAlign or Enum.TextXAlignment.Center,
		TextSize = 13,
		Visible = (options.sub or "") ~= "",
		ZIndex = button.ZIndex + 1,
	})

	-- Marca dourada de "pressionado" (prancha 37): barra curta na base, sem mexer no layout.
	local pressMark = Components.frame(button, "PressMark", {
		Size = UDim2.new(1, -24, 0, 3),
		Position = UDim2.new(0, 12, 1, -5),
		BackgroundColor3 = Theme.colors.goldDark,
		Visible = false,
		ZIndex = button.ZIndex + 2,
		Active = false,
	})
	Components.corner(pressMark, 2)

	local kind: ButtonKind = options.kind or "secondary"
	local baseText = options.text
	local baseSub = options.sub or ""
	local available, selected, pending, hovered, focusedNow = true, false, false, false, false
	local result: "none" | "success" | "error" = "none"
	local resultToken = 0
	local reason: string? = nil
	local handler: (() -> ())? = options.onActivate
	local connections: { RBXScriptConnection } = {}
	local alive = true

	local self = {} :: Button
	self.instance = button
	self.label = label
	self.sub = sub

	local function currentStyle(): KindStyle
		if result == "success" then
			return SUCCESS
		elseif result == "error" then
			return ERROR
		elseif pending then
			return PENDING
		elseif not available then
			return DISABLED
		elseif selected then
			return SUCCESS -- selecionado usa preenchimento dourado + ícone de seleção
		end
		return KINDS[kind]
	end

	local function applyLabels()
		if result == "success" then
			return
		end
		if result == "error" then
			return
		end
		if pending then
			return
		end
		if not available and reason and reason ~= "" and options.reasonAsLabel then
			label.Text = reason
			sub.Visible = false
		else
			label.Text = if selected then "✓ " .. baseText else baseText
			local subText = if not available and reason and reason ~= "" then reason else baseSub
			sub.Text = subText
			sub.Visible = subText ~= ""
		end
		label.Position = if sub.Visible then UDim2.new(0, textLeft, 0, -7) else UDim2.new(0, textLeft, 0, 0)
	end

	local function applyStyle()
		local style = currentStyle()
		button.BackgroundColor3 = style.bg
		label.TextColor3 = style.fg
		sub.TextColor3 = if available and result == "none" and not pending then Theme.colors.muted else style.fg
		if iconHandle then
			iconHandle:setColor(style.fg)
		end
		-- foco por teclado usa contorno cyan de 3 px, sempre visível em qualquer estado
		if focusedNow then
			stroke.Color = Theme.colors.cyan
			stroke.Thickness = Theme.sizes.focusStroke
		else
			stroke.Color = style.stroke
			stroke.Thickness = if hovered
					and available
					and not pending
				then Theme.sizes.focusStroke
				else Theme.sizes.stroke
		end
		-- Active=false impede que um botão indisponível engula o toque de outra coisa útil,
		-- mas ele continua Selectable para explicar o motivo pelo foco.
		button.Active = available and not pending
		button.AutoButtonColor = false
	end

	local function refresh()
		applyLabels()
		applyStyle()
	end

	local function settleScale()
		local target = if available and not pending and (hovered or focusedNow) then 1.03 else 1
		Anim.scale(scale, target, "hover_focus")
	end

	function self.setText(_, text: string, newSub: string?)
		baseText = text
		if newSub ~= nil then
			baseSub = newSub
		end
		refresh()
	end

	function self.setKind(_, newKind: ButtonKind)
		kind = newKind
		applyStyle()
	end

	function self.setAvailable(_, value: boolean, newReason: string?)
		available = value
		reason = newReason
		refresh()
		settleScale()
	end

	function self.setSelected(_, value: boolean)
		selected = value
		refresh()
	end

	function self.setPending(_, value: boolean, text: string?)
		pending = value
		if value then
			result = "none"
			resultToken += 1
			label.Text = text or L("common.confirming")
			sub.Visible = false
			label.Position = UDim2.new(0, textLeft, 0, 0)
		end
		applyStyle()
		if not value then
			refresh()
		end
		settleScale()
	end

	function self.clearResult(_)
		resultToken += 1
		result = "none"
		refresh()
	end

	function self.flashSuccess(_, text: string?)
		pending = false
		result = "success"
		resultToken += 1
		local token = resultToken
		label.Text = "✓ " .. (text or L("common.confirmed"))
		sub.Visible = false
		applyStyle()
		task.delay(SUCCESS_HOLD, function()
			if alive and resultToken == token then
				result = "none"
				refresh()
			end
		end)
	end

	function self.showError(_, text: string?)
		pending = false
		result = "error" -- erro relevante fica até a próxima ação (não some sozinho)
		resultToken += 1
		label.Text = "! " .. (text or L("common.retry"))
		sub.Visible = false
		applyStyle()
	end

	function self.isAvailable(_): boolean
		return available and not pending
	end

	function self.onActivate(_, fn: () -> ())
		handler = fn
	end

	local function activate()
		if not alive or not available or pending then
			return
		end
		if result == "error" then
			result = "none"
			refresh()
		end
		Anim.scale(scale, 0.97, "press")
		pressMark.Visible = not Accessibility.reducedMotion()
		task.delay(0.1, function()
			if alive then
				pressMark.Visible = false
				settleScale()
			end
		end)
		if handler then
			handler()
		end
	end

	-- Activated cobre clique e toque. Nenhum outro evento confirma a ação.
	table.insert(connections, button.Activated:Connect(activate))
	table.insert(
		connections,
		button.MouseEnter:Connect(function()
			hovered = true
			applyStyle()
			settleScale()
		end)
	)
	table.insert(
		connections,
		button.MouseLeave:Connect(function()
			hovered = false
			applyStyle()
			settleScale()
		end)
	)
	table.insert(
		connections,
		button.SelectionGained:Connect(function()
			focusedNow = true
			applyStyle()
			settleScale()
		end)
	)
	table.insert(
		connections,
		button.SelectionLost:Connect(function()
			focusedNow = false
			applyStyle()
			settleScale()
		end)
	)

	local unregister = Focus.register(button, activate, function()
		-- indisponível continua navegável para o jogador ler o motivo; pendente sai da ordem
		return alive and not pending
	end, options.focusScope)

	function self.destroy(_)
		if not alive then
			return
		end
		alive = false
		resultToken += 1
		unregister()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		Anim.cancelAll(scale)
		Anim.cancelAll(button)
		button:Destroy()
	end

	refresh()
	button.Parent = parent
	return self
end

-- ---------------------------------------------------------------------------
-- StatChip: pastilha de estatística do HUD (Farol, Onda, Sucata)
-- ---------------------------------------------------------------------------

export type Chip = {
	instance: Frame,
	value: TextLabel,
	caption: TextLabel,
	setValue: (self: Chip, text: string) -> (),
	setColor: (self: Chip, color: Color3) -> (),
}

function Components.statChip(
	parent: Instance?,
	name: string,
	captionText: string,
	props: { [string]: any }?,
	iconKey: string?
): Chip
	local chip = Components.panel(parent, name, props, { radius = Theme.sizes.pillCorner, tape = true, shadow = false })
	Components.padding(chip, 12, 6)
	local layout = Components.list(chip, Enum.FillDirection.Horizontal, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	if iconKey then
		local handle = Components.icon(chip, iconKey, 18, { LayoutOrder = 1, ZIndex = chip.ZIndex + 1 })
		if handle then
			handle.instance.LayoutOrder = 1
		end
	end
	local caption = Components.label(chip, "Caption", captionText, {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.sizes.caption,
		Font = Theme.fonts.bodyBold,
		TextColor3 = Theme.colors.muted,
		TextWrapped = false,
		LayoutOrder = 2,
		ZIndex = chip.ZIndex + 1,
	})
	local value = Components.label(chip, "Value", "", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.sizes.numbers,
		Font = Theme.fonts.numbers,
		TextColor3 = Theme.colors.ink,
		TextWrapped = false,
		LayoutOrder = 3,
		ZIndex = chip.ZIndex + 1,
	})
	local self = {} :: Chip
	self.instance = chip
	self.value = value
	self.caption = caption
	function self.setValue(_, text: string)
		value.Text = text
	end
	function self.setColor(_, color: Color3)
		value.TextColor3 = color
	end
	return self
end

-- ---------------------------------------------------------------------------
-- ProgressBar: vida da base, chefe, recarga do Pulso, progresso de domínio
-- ---------------------------------------------------------------------------

export type ProgressBar = {
	instance: Frame,
	setProgress: (self: ProgressBar, alpha: number, animated: boolean?) -> (),
	setColor: (self: ProgressBar, color: Color3) -> (),
}

function Components.progressBar(parent: Instance?, name: string, props: { [string]: any }?, color: Color3?): ProgressBar
	local track = Components.frame(parent, name, props)
	track.BackgroundColor3 = Theme.colors.sageDeep
	Components.corner(track, 999)
	local fill = Components.frame(track, "Fill", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or Theme.colors.gold,
		ZIndex = track.ZIndex + 1,
		Active = false,
	})
	Components.corner(fill, 999)
	local self = {} :: ProgressBar
	self.instance = track
	function self.setProgress(_, alpha: number, animated: boolean?)
		local target = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		if animated and not Accessibility.reducedMotion() then
			Anim.play(fill, "balance", { Size = target })
		else
			Anim.cancelAll(fill)
			fill.Size = target
		end
	end
	function self.setColor(_, value: Color3)
		fill.BackgroundColor3 = value
	end
	return self
end

-- ---------------------------------------------------------------------------
-- Toggle: Ligado/Desligado com texto e ícone (cor nunca é a única pista)
-- ---------------------------------------------------------------------------

export type Toggle = {
	button: Button,
	setValue: (self: Toggle, value: boolean) -> (),
}

function Components.toggle(
	parent: Instance?,
	name: string,
	initial: boolean,
	onChange: (value: boolean) -> (),
	props: { [string]: any }?
): Toggle
	local value = initial
	local button = Components.button(parent, {
		name = name,
		text = "",
		kind = "secondary",
		size = (props and props.Size) or UDim2.fromOffset(150, Theme.sizes.buttonTarget),
		position = props and props.Position,
		layoutOrder = props and props.LayoutOrder,
		zIndex = props and props.ZIndex,
	})
	local self = {} :: Toggle
	self.button = button
	local function refresh()
		button:setText(if value then "✓ " .. L("common.on") else "○ " .. L("common.off"))
		button:setKind(if value then "primary" else "secondary")
	end
	function self.setValue(_, newValue: boolean)
		value = newValue
		refresh()
	end
	button:onActivate(function()
		value = not value
		refresh()
		onChange(value)
	end)
	refresh()
	return self
end

-- ---------------------------------------------------------------------------
-- Slider: aceita clique na trilha, arrasto e teclado (menos/mais), passos de 5%
-- ---------------------------------------------------------------------------

export type Slider = {
	instance: Frame,
	setValue: (self: Slider, value: number, silent: boolean?) -> (),
	destroy: (self: Slider) -> (),
}

function Components.slider(
	parent: Instance?,
	name: string,
	initial: number,
	onChange: (value: number) -> (),
	props: { [string]: any }?
): Slider
	local STEP = 0.05
	local value = math.clamp(initial, 0, 1)
	local row = Components.frame(parent, name, props)
	row.BackgroundTransparency = 1
	local layout = Components.list(row, Enum.FillDirection.Horizontal, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local valueLabel: TextLabel
	local bar: ProgressBar
	local minus: Button
	local plus: Button

	local function apply(newValue: number, notify: boolean)
		value = math.clamp(math.floor(newValue / STEP + 0.5) * STEP, 0, 1)
		valueLabel.Text = tostring(math.floor(value * 100 + 0.5)) .. "%"
		bar:setProgress(value, false)
		minus:setAvailable(value > 0, if value > 0 then nil else L("settings.atMinimum"))
		plus:setAvailable(value < 1, if value < 1 then nil else L("settings.atMaximum"))
		if notify then
			onChange(value)
		end
	end

	minus = Components.button(row, {
		name = "Minus",
		text = "−",
		kind = "secondary",
		icon = "ui_minus",
		size = UDim2.fromOffset(Theme.sizes.buttonTarget, Theme.sizes.buttonTarget),
		layoutOrder = 1,
		onActivate = function()
			apply(value - STEP, true)
		end,
	})
	minus.label.Text = ""

	local trackHolder = Components.frame(row, "Track", {
		Size = UDim2.new(1, -(Theme.sizes.buttonTarget * 2 + 90), 0, Theme.sizes.buttonTarget),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	})
	-- a trilha inteira é clicável: o slider nunca exige arrasto preciso
	local trackButton = Instance.new("TextButton")
	trackButton.Name = "TrackButton"
	trackButton.Text = ""
	trackButton.AutoButtonColor = false
	trackButton.BackgroundTransparency = 1
	trackButton.Size = UDim2.fromScale(1, 1)
	trackButton.Selectable = false
	trackButton.Parent = trackHolder
	bar = Components.progressBar(trackHolder, "Bar", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0.5, -5),
		ZIndex = trackButton.ZIndex + 1,
	}, Theme.colors.gold)
	Components.stroke(bar.instance, Theme.colors.ink, 2)

	valueLabel = Components.label(row, "Value", "", {
		Size = UDim2.fromOffset(64, 24),
		TextSize = Theme.sizes.bodyLarge,
		Font = Theme.fonts.numbers,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		LayoutOrder = 3,
	})

	plus = Components.button(row, {
		name = "Plus",
		text = "+",
		kind = "secondary",
		icon = "ui_plus",
		size = UDim2.fromOffset(Theme.sizes.buttonTarget, Theme.sizes.buttonTarget),
		layoutOrder = 4,
		onActivate = function()
			apply(value + STEP, true)
		end,
	})
	plus.label.Text = ""

	local connections: { RBXScriptConnection } = {}
	local dragging = false
	local function valueFromX(x: number): number
		local absolute = bar.instance.AbsolutePosition.X
		local width = math.max(bar.instance.AbsoluteSize.X, 1)
		return (x - absolute) / width
	end
	table.insert(
		connections,
		trackButton.MouseButton1Down:Connect(function(x: number)
			dragging = true
			apply(valueFromX(x), true)
		end)
	)
	table.insert(
		connections,
		trackButton.MouseMoved:Connect(function(x: number)
			if dragging then
				apply(valueFromX(x), true)
			end
		end)
	)
	table.insert(
		connections,
		trackButton.MouseButton1Up:Connect(function()
			dragging = false
		end)
	)
	table.insert(
		connections,
		trackButton.MouseLeave:Connect(function()
			dragging = false
		end)
	)

	local self = {} :: Slider
	self.instance = row
	function self.setValue(_, newValue: number, silent: boolean?)
		apply(newValue, not silent)
	end
	function self.destroy(_)
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		minus:destroy()
		plus:destroy()
		row:Destroy()
	end
	apply(value, false)
	return self
end

-- ---------------------------------------------------------------------------
-- Tooltip: aparece no foco e no toque informativo, sem impedir a tarefa
-- ---------------------------------------------------------------------------

function Components.tooltip(host: GuiObject, text: string): () -> ()
	local bubble = Components.panel(host, "Tooltip", {
		Size = UDim2.fromOffset(240, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 0, 1, 6),
		BackgroundColor3 = Theme.colors.ink,
		Visible = false,
		ZIndex = host.ZIndex + 20,
		Active = false,
	}, { radius = 10, shadow = false, color = Theme.colors.ink, strokeColor = Theme.colors.ink })
	Components.padding(bubble, 10, 8)
	Components.label(bubble, "Text", text, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = Theme.colors.cream,
		TextSize = Theme.sizes.caption,
		ZIndex = bubble.ZIndex + 1,
	})
	local connections: { RBXScriptConnection } = {}
	local function show()
		bubble.Visible = true
	end
	local function hide()
		bubble.Visible = false
	end
	table.insert(connections, host.MouseEnter:Connect(show))
	table.insert(connections, host.MouseLeave:Connect(hide))
	table.insert(connections, host.SelectionGained:Connect(show))
	table.insert(connections, host.SelectionLost:Connect(hide))
	return function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		bubble:Destroy()
	end
end

-- ---------------------------------------------------------------------------
-- EmptyState: espaço vazio é intencional e não recebe alerta vermelho
-- ---------------------------------------------------------------------------

function Components.emptyState(parent: Instance?, name: string, text: string, props: { [string]: any }?): Frame
	local holder = Components.frame(parent, name, props)
	holder.BackgroundTransparency = 1
	Components.label(holder, "Text", text, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextSize = Theme.sizes.body,
	})
	return holder
end

-- Divisória sutil entre blocos de uma ficha
function Components.divider(parent: Instance?, order: number): Frame
	return Components.frame(parent, "Divider" .. order, {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.colors.sageDeep,
		LayoutOrder = order,
		Active = false,
	})
end

return Components
