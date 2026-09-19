--!strict
-- Biblioteca de componentes em Fusion: tudo que a interface desenha sai daqui.
--
-- Linguagem visual do revamp (direção de arte "brinquedo de quintal"):
--   * superfícies com gradiente sutil, contorno de tinta e sombra projetada;
--   * botões com chanfro inferior (a "espessura" do doce) que afunda ao toque;
--   * ícones reais de Config/UiIcons, com glifo de reserva quando o upload não existe;
--   * nenhuma prancha do pacote de UI vira imagem de tela.
--
-- Nada aqui guarda estado de jogo: os componentes recebem estados Fusion (ou valores crus) e
-- devolvem instâncias. Quem liga isso aos átomos Charm é State/Bridge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiIcons = require(ReplicatedStorage.Shared.Config.UiIcons)
local Fusion = require(ReplicatedStorage.Shared.Lib.Fusion)
local Theme = require(script.Parent.Parent.View.Theme)
local Accessibility = require(script.Parent.Accessibility)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local Kit = {}

export type Scope = Fusion.Scope<any>
export type Used<T> = Fusion.UsedAs<T>

local RADIUS = {
	panel = Theme.sizes.panelCorner,
	button = Theme.sizes.corner,
	pill = 999,
	chip = 14,
}

Kit.radius = RADIUS

-- Um escopo novo por tela. `Fusion.doCleanup(scope)` derruba tudo junto.
function Kit.scope(): Scope
	return Fusion.scoped(Fusion)
end

local function motion(): boolean
	return not Accessibility.reducedMotion()
end

-- ---------------------------------------------------------------------------
-- Primitivas
-- ---------------------------------------------------------------------------

local function apply(target: { [any]: any }, extra: { [any]: any }?): { [any]: any }
	if extra then
		for key, value in pairs(extra) do
			target[key] = value
		end
	end
	return target
end

-- Lista de filhos heterogênea. Sem isto, Luau infere o tipo do array pelo primeiro elemento
-- (um UIListLayout, por exemplo) e recusa os demais.
function Kit.children(...: any): { any }
	return { ... }
end

-- Leitura de um estado dentro de um Computed sem que Luau unifique os tipos de dois `use`
-- diferentes na mesma closure (limitação conhecida com funções genéricas).
function Kit.read<T>(use: Fusion.Use, target: Used<T>): T
	return (use :: any)(target)
end

function Kit.corner(scope: Scope, radius: number): UICorner
	return scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) })
end

function Kit.stroke(scope: Scope, color: Used<Color3>?, thickness: number?): UIStroke
	return scope:New("UIStroke")({
		Color = color or Theme.colors.ink,
		Thickness = thickness or Theme.sizes.stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(scope: Scope, horizontal: number, vertical: number?): UIPadding
	local v = vertical or horizontal
	return scope:New("UIPadding")({
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		PaddingTop = UDim.new(0, v),
		PaddingBottom = UDim.new(0, v),
	})
end

function Kit.list(scope: Scope, props: { [any]: any }?): UIListLayout
	return scope:New("UIListLayout")(apply({
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, props))
end

function Kit.grid(scope: Scope, cell: UDim2, gap: number, props: { [any]: any }?): UIGridLayout
	return scope:New("UIGridLayout")(apply({
		CellSize = cell,
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, props))
end

-- Gradiente vertical claro->escuro derivado da própria cor de fundo (dá volume sem outra cor).
function Kit.lift(scope: Scope, color: Color3, amount: number?): UIGradient
	local k = amount or 0.1
	local h, s, v = color:ToHSV()
	return scope:New("UIGradient")({
		Rotation = 90,
		Color = ColorSequence.new(
			Color3.fromHSV(h, math.max(s - k * 0.35, 0), math.min(v + k, 1)),
			Color3.fromHSV(h, math.min(s + k * 0.2, 1), math.max(v - k * 0.5, 0))
		),
	})
end

function Kit.text(scope: Scope, props: { [any]: any }): TextLabel
	-- TextSize pode chegar como número ou como estado Fusion (tela compacta, por exemplo).
	-- A preferência de texto ampliado do Roblox multiplica os dois casos.
	local rawSize = props.TextSize or Theme.sizes.body
	local isState = typeof(rawSize) == "table"
	local scaledSize: any = if isState
		then scope:Computed(function(use)
			return Accessibility.scaleText(Kit.read(use, rawSize))
		end)
		else Accessibility.scaleText(rawSize)
	local merged: { [any]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.fonts.body,
		TextColor3 = Theme.colors.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Size = if isState then UDim2.new(1, 0, 0, 24) else UDim2.new(1, 0, 0, math.ceil(rawSize * 1.4)),
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	merged.TextSize = scaledSize
	return scope:New("TextLabel")(merged)
end

function Kit.title(scope: Scope, props: { [any]: any }): TextLabel
	local merged = apply({ Font = Theme.fonts.title, TextSize = Theme.sizes.title }, props)
	return Kit.text(scope, merged)
end

function Kit.caption(scope: Scope, props: { [any]: any }): TextLabel
	local merged = apply({
		Font = Theme.fonts.bodyMedium,
		TextSize = Theme.sizes.caption,
		TextColor3 = Theme.colors.muted,
	}, props)
	return Kit.text(scope, merged)
end

-- Ícone publicado (ImageLabel) ou glifo de reserva enquanto o upload não existe.
function Kit.icon(scope: Scope, key: string, size: number, props: { [any]: any }?): GuiObject?
	local def = UiIcons[key]
	if not def then
		return nil
	end
	local base = apply({
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Active = false,
	}, props)
	if def.image then
		base.Image = def.image
		base.ScaleType = Enum.ScaleType.Fit
		base.ImageColor3 = base.ImageColor3 or Theme.colors.ink
		return scope:New("ImageLabel")(base)
	end
	base.Text = def.glyph
	base.TextSize = math.floor(size * 0.9)
	base.Font = Theme.fonts.bodyBold
	base.TextXAlignment = Enum.TextXAlignment.Center
	base.TextYAlignment = Enum.TextYAlignment.Center
	base.TextColor3 = base.ImageColor3 or Theme.colors.ink
	base.ImageColor3 = nil
	base.TextWrapped = false
	return scope:New("TextLabel")(base)
end

function Kit.scroller(scope: Scope, props: { [any]: any }): ScrollingFrame
	return scope:New("ScrollingFrame")(apply({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, props))
end

-- Ícone sobre um disco claro. A arte dos 24 ícones é tinta escura com fundo transparente e
-- ImageColor3 multiplica, então clarear por tinta é impossível: em faixa escura o ícone precisa
-- do disco atrás para existir.
function Kit.iconBadge(scope: Scope, key: string, size: number, props: { [any]: any }?): GuiObject?
	local icon = Kit.icon(scope, key, math.floor(size * 0.62), {
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = ((props and props.ZIndex) or 3) + 1,
	})
	if not icon then
		return nil
	end
	local badge: { [any]: any } = {
		Name = key .. "Badge",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		Active = false,
		ZIndex = (props and props.ZIndex) or 3,
		[Children] = Kit.children(Kit.corner(scope, 9999), icon),
	}
	if props then
		for key_, value in pairs(props) do
			if key_ ~= "ZIndex" then
				badge[key_] = value
			end
		end
	end
	return scope:New("Frame")(badge)
end

-- ---------------------------------------------------------------------------
-- Superfícies
-- ---------------------------------------------------------------------------

export type PanelProps = {
	name: string?,
	size: Used<UDim2>?,
	position: Used<UDim2>?,
	anchorPoint: Vector2?,
	layoutOrder: Used<number>?,
	visible: Used<boolean>?,
	zIndex: number?,
	automaticSize: Enum.AutomaticSize?,
	color: Used<Color3>?,
	strokeColor: Used<Color3>?,
	radius: number?,
	shadow: boolean?,
	gloss: boolean?,
	padding: number?,
	paddingVertical: number?,
	layout: Instance?,
	children: { any }?,
	-- filhos posicionados à mão (selo de atalho, botão de fechar): ficam fora da fila do layout
	overlay: { any }?,
	-- painel que cobre o tabuleiro: engole o toque em vez de deixar passar para a célula atrás
	blocking: boolean?,
}

-- Painel do revamp: um suporte transparente com [sombra, superfície]. A sombra é irmã da
-- superfície porque, com ZIndexBehavior.Sibling, um filho nunca desenha atrás do pai.
function Kit.panel(scope: Scope, props: PanelProps): Frame
	local radius = props.radius or RADIUS.panel
	local color = props.color or Theme.colors.paper
	local growsY = props.automaticSize == Enum.AutomaticSize.Y or props.automaticSize == Enum.AutomaticSize.XY
	local surfaceChildren: { any } = {
		Kit.corner(scope, radius),
		Kit.stroke(scope, props.strokeColor or Theme.colors.ink),
	}
	if typeof(color) == "Color3" then
		table.insert(surfaceChildren, Kit.lift(scope, color :: Color3, 0.08))
	end
	if props.padding then
		table.insert(surfaceChildren, Kit.padding(scope, props.padding, props.paddingVertical))
	end
	if props.gloss ~= false then
		table.insert(
			surfaceChildren,
			scope:New("Frame")({
				Name = "Gloss",
				Size = UDim2.new(1, -6, 0.48, 0),
				Position = UDim2.fromOffset(3, 3),
				BackgroundColor3 = Theme.colors.white,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = 0,
				[Children] = {
					Kit.corner(scope, math.max(radius - 3, 2)),
					scope:New("UIGradient")({
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				},
			})
		)
	end
	-- Com layout, o conteúdo vai para um filho próprio: um UIListLayout enfileira TODOS os filhos,
	-- e o lustro decorativo acabava virando o primeiro item da lista (foi o que empurrou o nome e
	-- o custo para fora das cartas de torre na primeira sessão de Play).
	if props.layout then
		local contentChildren: { any } = { props.layout }
		for _, child in ipairs(props.children or {}) do
			table.insert(contentChildren, child)
		end
		table.insert(
			surfaceChildren,
			scope:New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				-- num painel que cresce com o conteúdo, o quadro interno é quem tem altura
				-- automática: deixá-lo em 100% da superfície (que também cresce) inflava tudo
				Size = if growsY then UDim2.new(1, 0, 0, 0) else UDim2.fromScale(1, 1),
				AutomaticSize = props.automaticSize,
				ZIndex = (props.zIndex or 1) + 1,
				[Children] = contentChildren,
			})
		)
	else
		for _, child in ipairs(props.children or {}) do
			table.insert(surfaceChildren, child)
		end
	end
	for _, child in ipairs(props.overlay or {}) do
		table.insert(surfaceChildren, child)
	end

	local holderChildren: { any } = {}
	-- Num painel que cresce com o conteúdo a sombra não pode ser filha do suporte: ela fica 8 px
	-- maior que ele, e AutomaticSize mede os filhos — o painel crescia sozinho a cada quadro
	-- (era o "cartão de tutorial com um vão enorme" da primeira sessão de Play).
	if props.shadow ~= false and not growsY then
		table.insert(
			holderChildren,
			scope:New("Frame")({
				Name = "Shadow",
				Size = UDim2.new(1, 8, 1, 8),
				Position = UDim2.fromOffset(-4, 2),
				BackgroundColor3 = Theme.colors.inkDeep,
				BackgroundTransparency = 0.8,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = 0,
				[Children] = { Kit.corner(scope, radius + 4) },
			})
		)
	end
	table.insert(
		holderChildren,
		scope:New("Frame")({
			Name = "Surface",
			Size = if growsY then UDim2.new(1, 0, 0, 0) else UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Active = props.blocking == true,
			ZIndex = 1,
			AutomaticSize = props.automaticSize,
			[Children] = surfaceChildren,
		})
	)

	return scope:New("Frame")({
		Name = props.name or "Panel",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		Visible = props.visible,
		ZIndex = props.zIndex or 1,
		AutomaticSize = props.automaticSize,
		[Children] = holderChildren,
	})
end

-- ---------------------------------------------------------------------------
-- Botão
-- ---------------------------------------------------------------------------

export type ButtonKind = "primary" | "secondary" | "danger" | "ghost" | "dark" | "cyan" | "quiet"

type KindStyle = { bg: Color3, fg: Color3, stroke: Color3, bevel: Color3 }

local KINDS: { [string]: KindStyle } = {
	primary = {
		bg = Theme.colors.gold,
		fg = Theme.colors.ink,
		stroke = Theme.colors.ink,
		bevel = Theme.colors.goldDark,
	},
	secondary = {
		bg = Theme.colors.paper,
		fg = Theme.colors.ink,
		stroke = Theme.colors.ink,
		bevel = Theme.colors.creamDark,
	},
	danger = {
		bg = Theme.colors.dangerSoft,
		fg = Theme.colors.danger,
		stroke = Theme.colors.danger,
		bevel = Theme.colors.danger,
	},
	ghost = {
		bg = Theme.colors.paper,
		fg = Theme.colors.muted,
		stroke = Theme.colors.muted,
		bevel = Theme.colors.creamDark,
	},
	dark = { bg = Theme.colors.ink, fg = Theme.colors.cream, stroke = Theme.colors.ink, bevel = Theme.colors.inkDeep },
	cyan = { bg = Theme.colors.cyan, fg = Theme.colors.ink, stroke = Theme.colors.ink, bevel = Theme.colors.tealDark },
	quiet = {
		bg = Theme.colors.sage,
		fg = Theme.colors.ink,
		stroke = Theme.colors.muted,
		bevel = Theme.colors.sageDeep,
	},
}

local DISABLED: KindStyle = {
	bg = Theme.colors.sage,
	fg = Theme.colors.muted,
	stroke = Theme.colors.muted,
	bevel = Theme.colors.sageDeep,
}

export type ButtonProps = {
	name: string?,
	text: Used<string>,
	sub: Used<string>?,
	kind: Used<ButtonKind>?,
	icon: string?,
	size: Used<UDim2>?,
	position: Used<UDim2>?,
	anchorPoint: Vector2?,
	layoutOrder: Used<number>?,
	visible: Used<boolean>?,
	zIndex: number?,
	textSize: number?,
	disabled: Used<boolean>?,
	selected: Used<boolean>?,
	onActivate: (() -> ())?,
}

-- Botão de doce: um suporte com a "espessura" escura atrás e o corpo por cima. Ao apertar, o
-- corpo desce e a espessura some — é o mesmo gesto de um botão físico.
--
-- Por que suporte em vez de uma barra dentro do botão: a barra desenhada dentro cobria a segunda
-- linha do rótulo (apareceu na primeira sessão de Play como um traço escuro em cima do texto).
function Kit.button(scope: Scope, props: ButtonProps): Frame
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)

	local disabled = scope:Computed(function(use)
		return use(props.disabled) == true
	end)
	local style = scope:Computed(function(use): KindStyle
		if use(disabled) then
			return DISABLED
		end
		if use(props.selected) == true then
			return KINDS.primary
		end
		return KINDS[use(props.kind) or "secondary"] or KINDS.secondary
	end)

	local THICKNESS = 5
	local sink = scope:Spring(
		scope:Computed(function(use)
			if not motion() then
				return 0
			end
			return if use(pressed) and not use(disabled) then THICKNESS else 0
		end),
		45,
		1
	)
	local scale = scope:Spring(
		scope:Computed(function(use)
			if not motion() then
				return 1
			end
			return if use(hovered) and not use(disabled) then 1.02 else 1
		end),
		30,
		0.85
	)

	local radius = RADIUS.button
	local textLeft = if props.icon then 42 else 14

	-- em botão escuro o ícone só aparece sobre um disco claro (a arte é tinta escura)
	local iconOnDark = (props.kind == "dark")
	local iconChild = if props.icon
		then (if iconOnDark
			then Kit.iconBadge(scope, props.icon, 28, {
				Position = UDim2.new(0, 10, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 4,
			})
			else Kit.icon(scope, props.icon, 22, {
				Position = UDim2.new(0, 12, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 4,
			}))
		else nil

	local hasSub = scope:Computed(function(use)
		return (use(props.sub) or "") ~= ""
	end)

	local label = Kit.text(scope, {
		Name = "Label",
		Text = props.text,
		Size = scope:Computed(function(use)
			return UDim2.new(1, -(textLeft + 14), 1, if use(hasSub) then -18 else 0)
		end),
		Position = UDim2.new(0, textLeft, 0, 0),
		Font = Theme.fonts.bodyBold,
		TextSize = props.textSize or Theme.sizes.button,
		TextColor3 = scope:Computed(function(use)
			return use(style).fg
		end),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})

	local sub = Kit.caption(scope, {
		Name = "Sub",
		Text = scope:Computed(function(use)
			return use(props.sub) or ""
		end),
		Visible = hasSub,
		Size = UDim2.new(1, -(textLeft + 14), 0, 16),
		Position = UDim2.new(0, textLeft, 1, -19),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = scope:Computed(function(use)
			return if use(disabled) then Theme.colors.muted else use(style).fg
		end),
		ZIndex = 4,
	})

	local bodyChildren: { any } = {
		Kit.corner(scope, radius),
		Kit.stroke(
			scope,
			scope:Computed(function(use)
				return use(style).stroke
			end)
		),
		-- lustro curto no topo, discreto: o botão é de brinquedo, não de vidro
		scope:New("Frame")({
			Name = "Gloss",
			Size = UDim2.new(1, -10, 0.4, 0),
			Position = UDim2.fromOffset(5, 4),
			BackgroundColor3 = Theme.colors.white,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = 3,
			[Children] = Kit.children(
				Kit.corner(scope, math.max(radius - 4, 2)),
				scope:New("UIGradient")({
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})
			),
		}),
		label,
		sub,
	}
	if iconChild then
		table.insert(bodyChildren, iconChild)
	end

	local body: { [any]: any } = {
		Name = "Body",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = scope:Computed(function(use)
			return use(style).bg
		end),
		Size = UDim2.new(1, 0, 1, -THICKNESS),
		Position = scope:Computed(function(use)
			return UDim2.fromOffset(0, use(sink))
		end),
		ZIndex = 3,
		Selectable = true,
		Active = scope:Computed(function(use)
			return not use(disabled)
		end),
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
			pressed:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
		end,
		-- só Activated confirma o toque (nunca InputEnded)
		[OnEvent("Activated")] = function()
			if peek(disabled) then
				return
			end
			if props.onActivate then
				props.onActivate()
			end
		end,
		[Children] = bodyChildren,
	}

	return scope:New("Frame")({
		Name = props.name or "Button",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromOffset(180, Theme.sizes.buttonTarget),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		Visible = props.visible,
		ZIndex = props.zIndex or 2,
		[Children] = Kit.children(
			scope:New("UIScale")({ Scale = scale }),
			scope:New("UISizeConstraint")({ MinSize = Vector2.new(Theme.sizes.buttonMin, Theme.sizes.buttonMin) }),
			-- espessura: fica atrás do corpo e aparece na base enquanto o botão está "solto"
			scope:New("Frame")({
				Name = "Thickness",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = scope:Computed(function(use)
					return use(style).bevel
				end),
				BorderSizePixel = 0,
				Active = false,
				ZIndex = 2,
				[Children] = Kit.children(
					Kit.corner(scope, radius),
					Kit.stroke(
						scope,
						scope:Computed(function(use)
							return use(style).stroke
						end)
					)
				),
			}),
			scope:New("TextButton")(body)
		),
	})
end

-- ---------------------------------------------------------------------------
-- Ficha de estado (HUD): ícone + rótulo + valor
-- ---------------------------------------------------------------------------

export type ChipProps = {
	name: string?,
	icon: string?,
	caption: Used<string>?,
	value: Used<string>,
	accent: Used<Color3>?,
	width: Used<UDim2>?,
	layoutOrder: number?,
	progress: Used<number>?, -- 0..1 desenha uma barra fina embaixo do valor
	compact: boolean?,
}

function Kit.chip(scope: Scope, props: ChipProps): Frame
	local accent = props.accent or Theme.colors.cream
	local compact = props.compact == true
	local children: { any } = {
		Kit.corner(scope, RADIUS.chip),
		Kit.stroke(scope, Theme.colors.inkDeep, 2),
		Kit.padding(scope, if compact then 8 else 12, if compact then 4 else 6),
		Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	if props.icon then
		local iconChild = Kit.iconBadge(scope, props.icon, if compact then 24 else 30, {
			LayoutOrder = 1,
			ZIndex = 3,
		})
		if iconChild then
			table.insert(children, iconChild)
		end
	end
	local textChildren: { any } = {
		Kit.text(scope, {
			Name = "Value",
			Text = props.value,
			Font = Theme.fonts.numbers,
			TextSize = if compact then 16 else 20,
			TextColor3 = accent,
			Size = UDim2.new(1, 0, 0, if compact then 18 else 24),
			LayoutOrder = 2,
			ZIndex = 3,
		}),
	}
	if props.caption then
		table.insert(
			textChildren,
			1,
			Kit.caption(scope, {
				Name = "Caption",
				Text = props.caption,
				TextSize = if compact then 9 else 11,
				TextColor3 = Theme.colors.cyan,
				Font = Theme.fonts.bodyBold,
				Size = UDim2.new(1, 0, 0, if compact then 11 else 13),
				LayoutOrder = 1,
				ZIndex = 3,
			})
		)
	end
	if props.progress then
		table.insert(
			textChildren,
			scope:New("Frame")({
				Name = "BarBack",
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundColor3 = Theme.colors.inkDeep,
				BorderSizePixel = 0,
				LayoutOrder = 3,
				ZIndex = 3,
				[Children] = {
					Kit.corner(scope, 999),
					scope:New("Frame")({
						Name = "Bar",
						Size = scope:Spring(
							scope:Computed(function(use)
								return UDim2.fromScale(math.clamp(use(props.progress) or 1, 0, 1), 1)
							end),
							22,
							1
						),
						BackgroundColor3 = accent,
						BorderSizePixel = 0,
						ZIndex = 4,
						[Children] = { Kit.corner(scope, 999) },
					}),
				},
			})
		)
	end
	local textBlock: { any } =
		{ Kit.list(scope, { Padding = UDim.new(0, 1), VerticalAlignment = Enum.VerticalAlignment.Center }) }
	for _, child in ipairs(textChildren) do
		table.insert(textBlock, child)
	end
	table.insert(
		children,
		scope:New("Frame")({
			Name = "Text",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, if compact then 64 else 92, 1, 0),
			LayoutOrder = 2,
			ZIndex = 3,
			[Children] = textBlock,
		})
	)

	return scope:New("Frame")({
		Name = props.name or "Chip",
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = props.width or UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.layoutOrder,
		ZIndex = 2,
		[Children] = children,
	})
end

-- ---------------------------------------------------------------------------
-- Etiqueta e barra
-- ---------------------------------------------------------------------------

function Kit.tag(scope: Scope, props: { [any]: any }): Frame
	local color = props.color or Theme.colors.sage
	local inner: { any } = {
		Kit.corner(scope, RADIUS.pill),
		Kit.padding(scope, 10, 3),
		Kit.text(scope, {
			Text = props.text,
			TextSize = 12,
			Font = Theme.fonts.bodyBold,
			TextColor3 = props.textColor or Theme.colors.ink,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextWrapped = false,
			ZIndex = 3,
		}),
	}
	local definition: { [any]: any } = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		[Children] = inner,
	}
	if props.frame then
		for key, value in pairs(props.frame) do
			definition[key] = value
		end
	end
	return scope:New("Frame")(definition)
end

export type BarProps = {
	value: Used<number>, -- 0..1
	color: Used<Color3>?,
	background: Used<Color3>?,
	height: number?,
	size: Used<UDim2>?,
	layoutOrder: number?,
}

function Kit.bar(scope: Scope, props: BarProps): Frame
	local height = props.height or 10
	return scope:New("Frame")({
		Name = "Bar",
		BackgroundColor3 = props.background or Theme.colors.inkDeep,
		BorderSizePixel = 0,
		Size = props.size or UDim2.new(1, 0, 0, height),
		LayoutOrder = props.layoutOrder,
		[Children] = {
			Kit.corner(scope, 999),
			scope:New("Frame")({
				Name = "Fill",
				BackgroundColor3 = props.color or Theme.colors.gold,
				BorderSizePixel = 0,
				Size = scope:Spring(
					scope:Computed(function(use)
						return UDim2.fromScale(math.clamp(use(props.value), 0, 1), 1)
					end),
					20,
					1
				),
				ZIndex = 2,
				[Children] = {
					Kit.corner(scope, 999),
					scope:New("UIGradient")({
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.25),
							NumberSequenceKeypoint.new(1, 0),
						}),
						Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.85, 0.85, 0.85)),
					}),
				},
			}),
		},
	})
end

-- Área clicável transparente em volta de um conteúdo (cartões de mapa, de torre, de sala).
-- O visual fica nos filhos; aqui só existe o alvo de toque.
export type PressableProps = {
	name: string?,
	size: Used<UDim2>?,
	position: Used<UDim2>?,
	anchorPoint: Vector2?,
	layoutOrder: Used<number>?,
	visible: Used<boolean>?,
	zIndex: number?,
	disabled: Used<boolean>?,
	onActivate: (() -> ())?,
	children: { any },
}

function Kit.pressable(scope: Scope, props: PressableProps): TextButton
	local definition: { [any]: any } = {
		Name = props.name or "Pressable",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		Visible = props.visible,
		ZIndex = props.zIndex or 2,
		Selectable = true,
		Active = scope:Computed(function(use)
			return use(props.disabled) ~= true
		end),
		[OnEvent("Activated")] = function()
			if peek(props.disabled) == true then
				return
			end
			if props.onActivate then
				props.onActivate()
			end
		end,
		[Children] = props.children,
	}
	return scope:New("TextButton")(definition)
end

-- ---------------------------------------------------------------------------
-- Moldura de tela (cabeçalho + corpo)
-- ---------------------------------------------------------------------------

export type ScreenProps = {
	name: string,
	title: Used<string>,
	subtitle: Used<string>?,
	visible: Used<boolean>?,
	onBack: (() -> ())?,
	backText: Used<string>?,
	header: { any }?, -- conteúdo extra alinhado à direita do cabeçalho (saldo, filtros…)
	children: { any }?,
	bodyLayout: Instance?,
	scroll: boolean?,
}

export type Screen = { instance: Frame, body: GuiObject }

-- Moldura comum das telas de menu: faixa de título com "voltar" à esquerda, espaço livre à
-- direita para fichas e um corpo (rolável quando a tela pede).
function Kit.screen(scope: Scope, props: ScreenProps): Screen
	local headerChildren: { any } = {
		Kit.list(scope, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 14),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	if props.onBack then
		table.insert(
			headerChildren,
			Kit.button(scope, {
				name = "Back",
				text = props.backText or "‹",
				kind = "secondary",
				size = UDim2.fromOffset(72, Theme.sizes.buttonTarget),
				layoutOrder = 1,
				zIndex = 4,
				onActivate = props.onBack,
			})
		)
	end
	local titleBlock: { any } = {
		Kit.list(scope, { Padding = UDim.new(0, 2) }),
		Kit.title(scope, {
			Name = "Title",
			Text = props.title,
			TextSize = 30,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = 1,
			ZIndex = 4,
		}),
	}
	if props.subtitle then
		table.insert(
			titleBlock,
			Kit.caption(scope, {
				Name = "Subtitle",
				Text = props.subtitle,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 2,
				ZIndex = 4,
			})
		)
	end
	table.insert(
		headerChildren,
		scope:New("Frame")({
			Name = "Titles",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 420, 1, 0),
			LayoutOrder = 2,
			ZIndex = 4,
			[Children] = titleBlock,
		})
	)
	for index, child in ipairs(props.header or {}) do
		if typeof(child) == "Instance" and child:IsA("GuiObject") then
			child.LayoutOrder = 10 + index
		end
		table.insert(headerChildren, child)
	end

	local bodyChildren: { any } = {}
	if props.bodyLayout then
		table.insert(bodyChildren, props.bodyLayout)
	end
	for _, child in ipairs(props.children or {}) do
		table.insert(bodyChildren, child)
	end

	local body: GuiObject
	if props.scroll then
		body = Kit.scroller(scope, {
			Name = "Body",
			Size = UDim2.new(1, 0, 1, -104),
			Position = UDim2.fromOffset(0, 104),
			ZIndex = 2,
			[Children] = bodyChildren,
		})
	else
		body = scope:New("Frame")({
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -104),
			Position = UDim2.fromOffset(0, 104),
			ZIndex = 2,
			[Children] = bodyChildren,
		})
	end

	local instance = scope:New("Frame")({
		Name = props.name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -64, 1, -48),
		Position = UDim2.fromOffset(32, 24),
		Visible = props.visible,
		[Children] = Kit.children(
			scope:New("Frame")({
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 72),
				ZIndex = 3,
				[Children] = headerChildren,
			}),
			body
		),
	})
	return { instance = instance, body = body }
end

return Kit
