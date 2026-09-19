--!strict
-- Camada visual do revamp: profundidade, lustro, halo e cenário.
--
-- Tudo aqui é Frame/UIGradient/UIStroke nativo — nenhuma prancha vira imagem de tela e nenhum
-- rbxassetid é inventado. As cores saem de Theme (que vem de Config/UiTokens, já verificado em
-- contraste); as variações decorativas usadas aqui (forest, leaf, glowWarm, inkDeep) nunca
-- carregam texto.
--
-- Ordem das camadas: Theme -> Skin -> Components. Skin não conhece Components nem o HUD.
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.View.Theme)
local Accessibility = require(script.Parent.Accessibility)

local Skin = {}

local function cornerRadiusOf(target: GuiObject, fallback: number): number
	local corner = target:FindFirstChildOfClass("UICorner")
	if corner then
		return corner.CornerRadius.Offset
	end
	return fallback
end

local function makeFrame(parent: Instance?, name: string, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.BackgroundColor3 = Theme.colors.paper
	if props then
		for key, value in pairs(props) do
			(frame :: any)[key] = value
		end
	end
	frame.Parent = parent
	return frame
end

-- Construtores imperativos usados pelo tabuleiro (o HUD é Fusion; o tabuleiro é desenhado e
-- reciclado a 60 Hz, onde um sistema reativo só atrapalharia).
function Skin.frame(parent: Instance?, name: string, props: { [string]: any }?): Frame
	return makeFrame(parent, name, props)
end

function Skin.label(parent: Instance?, name: string, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Theme.fonts.body
	label.TextColor3 = Theme.colors.ink
	label.TextSize = Theme.sizes.body
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Active = false
	if props then
		for key, value in pairs(props) do
			(label :: any)[key] = value
		end
	end
	label.Parent = parent
	return label
end

function Skin.stroke(target: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.colors.ink
	stroke.Thickness = thickness or Theme.sizes.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
	return stroke
end

function Skin.corner(target: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = target
	return corner
end

-- ---------------------------------------------------------------------------
-- Gradientes
-- ---------------------------------------------------------------------------

-- Gradiente vertical simples (90°: topo -> base).
function Skin.gradient(target: GuiObject, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local existing = target:FindFirstChildOfClass("UIGradient")
	local gradient: UIGradient = if existing then existing else Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = target
	return gradient
end

-- Clareia o topo do próprio preenchimento (sem sobrepor outro Frame).
function Skin.lift(target: GuiObject, amount: number?): UIGradient
	local base = target.BackgroundColor3
	local k = amount or 0.12
	local h, s, v = base:ToHSV()
	local top = Color3.fromHSV(h, math.max(s - k * 0.35, 0), math.min(v + k, 1))
	local bottom = Color3.fromHSV(h, math.min(s + k * 0.2, 1), math.max(v - k * 0.5, 0))
	return Skin.gradient(target, top, bottom)
end

-- ---------------------------------------------------------------------------
-- Sombra projetada
-- ---------------------------------------------------------------------------

export type ShadowOptions = {
	offset: number?, -- deslocamento vertical em px
	spread: number?, -- quanto a sombra passa da silhueta, em px
	transparency: number?,
	color: Color3?,
	radius: number?,
}

-- Sombra como irmã do alvo (com ZIndexBehavior.Sibling, um filho nunca fica atrás do pai).
-- Acompanha posição, tamanho e âncora do alvo e morre junto com ele.
function Skin.dropShadow(target: GuiObject, options: ShadowOptions?): Frame?
	local parent = target.Parent
	if not parent or not parent:IsA("GuiObject") then
		return nil
	end
	local opts: ShadowOptions = options or {}
	local offset = opts.offset or 6
	local spread = opts.spread or 2
	local radius = opts.radius or cornerRadiusOf(target, Theme.sizes.panelCorner)
	local shadow = makeFrame(parent, target.Name .. "Shadow", {
		BackgroundColor3 = opts.color or Theme.colors.inkDeep,
		BackgroundTransparency = opts.transparency or 0.78,
		ZIndex = math.max(target.ZIndex - 1, 0),
		Visible = target.Visible,
	})
	Skin.corner(shadow, radius + spread)
	local function sync()
		shadow.AnchorPoint = target.AnchorPoint
		shadow.Size = target.Size + UDim2.fromOffset(spread * 2, spread * 2)
		shadow.Position = target.Position + UDim2.fromOffset(-spread, offset - spread)
		shadow.LayoutOrder = target.LayoutOrder
	end
	sync()
	-- Em layouts automáticos (UIListLayout) a posição é escrita pelo layout: o irmão extra
	-- atrapalharia a fila, então a sombra some e o painel usa só contorno.
	local layout = parent:FindFirstChildWhichIsA("UILayout")
	if layout then
		shadow:Destroy()
		return nil
	end
	target:GetPropertyChangedSignal("Position"):Connect(sync)
	target:GetPropertyChangedSignal("Size"):Connect(sync)
	target:GetPropertyChangedSignal("AnchorPoint"):Connect(sync)
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = target.Visible
	end)
	target.Destroying:Connect(function()
		shadow:Destroy()
	end)
	return shadow
end

-- ---------------------------------------------------------------------------
-- Lustro, chanfro e halo
-- ---------------------------------------------------------------------------

-- Faixa clara no topo do painel/botão (o "brilho de brinquedo" da direção de arte).
function Skin.gloss(target: GuiObject, strength: number?): Frame
	local radius = cornerRadiusOf(target, Theme.sizes.corner)
	local gloss = makeFrame(target, "Gloss", {
		Size = UDim2.new(1, -4, 0.52, 0),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Theme.colors.white,
		BackgroundTransparency = 1 - (strength or 0.22),
		ZIndex = target.ZIndex,
	})
	Skin.corner(gloss, math.max(radius - 2, 2))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = gloss
	return gloss
end

-- Chanfro inferior: a "espessura" do botão de doce. Some quando o botão afunda.
function Skin.bevel(target: GuiObject, color: Color3, height: number?): Frame
	local radius = cornerRadiusOf(target, Theme.sizes.corner)
	local h = height or 5
	local bevel = makeFrame(target, "Bevel", {
		Size = UDim2.new(1, -6, 0, h + radius),
		Position = UDim2.new(0, 3, 1, -(h + radius) - 1),
		BackgroundColor3 = color,
		ZIndex = target.ZIndex,
	})
	Skin.corner(bevel, math.max(radius - 2, 2))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = bevel
	return bevel
end

export type Halo = {
	instance: Frame,
	setActive: (self: Halo, active: boolean, color: Color3?) -> (),
}

-- Halo suave em volta de um elemento selecionado (irmão, como a sombra).
function Skin.halo(target: GuiObject, color: Color3?): Halo?
	local parent = target.Parent
	if not parent or not parent:IsA("GuiObject") or parent:FindFirstChildWhichIsA("UILayout") then
		return nil
	end
	local radius = cornerRadiusOf(target, Theme.sizes.corner)
	local halo = makeFrame(parent, target.Name .. "Halo", {
		BackgroundColor3 = color or Theme.colors.gold,
		BackgroundTransparency = 1,
		ZIndex = math.max(target.ZIndex - 1, 0),
		Visible = false,
	})
	Skin.corner(halo, radius + 8)
	local function sync()
		halo.AnchorPoint = target.AnchorPoint
		halo.Size = target.Size + UDim2.fromOffset(16, 16)
		halo.Position = target.Position + UDim2.fromOffset(-8, -8)
	end
	sync()
	target:GetPropertyChangedSignal("Position"):Connect(sync)
	target:GetPropertyChangedSignal("Size"):Connect(sync)
	target.Destroying:Connect(function()
		halo:Destroy()
	end)
	local self = {} :: Halo
	self.instance = halo
	function self.setActive(_, active: boolean, newColor: Color3?)
		if newColor then
			halo.BackgroundColor3 = newColor
		end
		halo.Visible = active
		local target_ = if active then 0.62 else 1
		if Accessibility.reducedMotion() then
			halo.BackgroundTransparency = target_
			return
		end
		TweenService:Create(halo, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { BackgroundTransparency = target_ })
			:Play()
	end
	return self
end

-- ---------------------------------------------------------------------------
-- Vinheta e cenário
-- ---------------------------------------------------------------------------

-- Escurecimento das bordas: quatro faixas com gradiente, sem cobrir o centro jogável.
function Skin.vignette(parent: GuiObject, strength: number?): Frame
	local alpha = strength or 0.55
	local holder = makeFrame(parent, "Vignette", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = parent.ZIndex + 1,
	})
	local edges: { { name: string, size: UDim2, position: UDim2, anchor: Vector2, rotation: number } } = {
		{ name = "Top", size = UDim2.new(1, 0, 0.3, 0), position = UDim2.new(), anchor = Vector2.zero, rotation = -90 },
		{
			name = "Bottom",
			size = UDim2.new(1, 0, 0.34, 0),
			position = UDim2.fromScale(0, 1),
			anchor = Vector2.new(0, 1),
			rotation = 90,
		},
		{
			name = "Left",
			size = UDim2.new(0.22, 0, 1, 0),
			position = UDim2.new(),
			anchor = Vector2.zero,
			rotation = 180,
		},
		{
			name = "Right",
			size = UDim2.new(0.22, 0, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			rotation = 0,
		},
	}
	for _, edge in ipairs(edges) do
		local band = makeFrame(holder, edge.name, {
			Size = edge.size,
			Position = edge.position,
			AnchorPoint = edge.anchor,
			BackgroundColor3 = Theme.colors.inkDeep,
			BackgroundTransparency = 1 - alpha,
			ZIndex = holder.ZIndex,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = band
	end
	return holder
end

export type Scenery = {
	instance: Frame,
	setTint: (self: Scenery, top: Color3, bottom: Color3) -> (),
	destroy: (self: Scenery) -> (),
}

-- Fundo ilustrado atrás do tabuleiro: céu em gradiente, folhagem nos cantos, feixes de luz,
-- partículas lentas e vinheta. Puramente decorativo (Active = false em tudo).
function Skin.scenery(parent: GuiObject): Scenery
	local root = makeFrame(parent, "Scenery", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.sage,
		ZIndex = 0,
	})
	-- Quintal de dia: o texto das telas é tinta escura sobre papel, então o fundo é claro.
	-- A folhagem escura entra só como moldura nas bordas.
	local sky = Skin.gradient(root, Theme.colors.cream, Theme.colors.sageDeep)
	sky.Rotation = 80

	-- folhagem: círculos grandes e translúcidos nos quatro cantos
	local blobs: { { x: number, y: number, size: number, color: Color3, alpha: number } } = {
		{ x = -0.1, y = -0.14, size = 0.44, color = Theme.colors.leaf, alpha = 0.3 },
		{ x = 0.1, y = -0.22, size = 0.32, color = Theme.colors.leafLight, alpha = 0.34 },
		{ x = 1.04, y = -0.16, size = 0.42, color = Theme.colors.leaf, alpha = 0.28 },
		{ x = 0.9, y = -0.24, size = 0.28, color = Theme.colors.leafLight, alpha = 0.3 },
		{ x = -0.12, y = 0.84, size = 0.48, color = Theme.colors.leaf, alpha = 0.32 },
		{ x = 0.05, y = 1, size = 0.34, color = Theme.colors.leafLight, alpha = 0.34 },
		{ x = 1.06, y = 0.88, size = 0.46, color = Theme.colors.leaf, alpha = 0.3 },
		{ x = 0.94, y = 1.02, size = 0.3, color = Theme.colors.leafLight, alpha = 0.36 },
	}
	for index, blob in ipairs(blobs) do
		local leaf = makeFrame(root, "Leaf" .. index, {
			Size = UDim2.fromScale(blob.size, blob.size * 1.15),
			Position = UDim2.fromScale(blob.x, blob.y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = blob.color,
			BackgroundTransparency = 1 - blob.alpha,
			Rotation = (index % 2 == 0) and 12 or -9,
			ZIndex = root.ZIndex + 1,
		})
		Skin.corner(leaf, 9999)
	end

	-- dois feixes de luz diagonais, bem discretos
	for index = 1, 2 do
		local beam = makeFrame(root, "Beam" .. index, {
			Size = UDim2.fromScale(0.16, 1.8),
			Position = UDim2.fromScale(0.18 + index * 0.3, -0.2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.colors.white,
			BackgroundTransparency = 0.88,
			Rotation = 16,
			ZIndex = root.ZIndex + 2,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = beam
	end

	-- poeira luminosa subindo devagar (só quando o movimento não está reduzido)
	if not Accessibility.reducedMotion() then
		for index = 1, 10 do
			local mote = makeFrame(root, "Mote" .. index, {
				Size = UDim2.fromOffset(4 + index % 3, 4 + index % 3),
				Position = UDim2.fromScale(0.05 + (index * 0.093) % 0.9, 0.2 + (index * 0.17) % 0.7),
				BackgroundColor3 = Theme.colors.glowWarm,
				BackgroundTransparency = 0.55,
				ZIndex = root.ZIndex + 3,
			})
			Skin.corner(mote, 9999)
			local rise = 0.25 + (index % 4) * 0.08
			local duration = 7 + (index % 5)
			task.spawn(function()
				while mote.Parent do
					local base = mote.Position
					local up = TweenService:Create(
						mote,
						TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Position = base - UDim2.fromScale(0, rise), BackgroundTransparency = 1 }
					)
					up:Play()
					up.Completed:Wait()
					if not mote.Parent then
						return
					end
					mote.Position = base
					mote.BackgroundTransparency = 0.55
					task.wait(0.4 + (index % 3) * 0.3)
				end
			end)
		end
	end

	-- vinheta discreta: escurece só o cantinho, sem apagar o texto das telas
	Skin.vignette(root, 0.22)

	local self = {} :: Scenery
	self.instance = root
	function self.setTint(_, top: Color3, bottom: Color3)
		sky.Color = ColorSequence.new(top, bottom)
	end
	function self.destroy(_)
		root:Destroy()
	end
	return self
end

-- ---------------------------------------------------------------------------
-- Superfícies prontas
-- ---------------------------------------------------------------------------

export type SurfaceOptions = {
	radius: number?,
	color: Color3?,
	strokeColor: Color3?,
	strokeThickness: number?,
	shadow: boolean?,
	gloss: number?,
	gradient: boolean?,
}

-- Painel do revamp: gradiente sutil, contorno, lustro e sombra projetada.
function Skin.surface(parent: Instance?, name: string, props: { [string]: any }?, options: SurfaceOptions?): Frame
	local opts: SurfaceOptions = options or {}
	local surface = makeFrame(parent, name, props)
	surface.Active = if props and props.Active ~= nil then props.Active else false
	surface.BackgroundColor3 = opts.color or (props and props.BackgroundColor3) or Theme.colors.paper
	local radius = opts.radius or Theme.sizes.panelCorner
	Skin.corner(surface, radius)
	local stroke = Instance.new("UIStroke")
	stroke.Color = opts.strokeColor or Theme.colors.ink
	stroke.Thickness = opts.strokeThickness or Theme.sizes.stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = surface
	if opts.gradient ~= false then
		Skin.lift(surface, 0.1)
	end
	if opts.shadow ~= false then
		Skin.dropShadow(surface, { radius = radius })
	end
	if opts.gloss and opts.gloss > 0 then
		Skin.gloss(surface, opts.gloss)
	end
	return surface
end

return Skin
