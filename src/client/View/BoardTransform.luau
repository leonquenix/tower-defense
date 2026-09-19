--!strict
-- Centraliza escala, zoom e deslocamento do tabuleiro. Todo input passa pela transformação inversa.
-- O tabuleiro mantém 16:10; o mundo (world) é escalado dentro de uma janela com recorte.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Grid = require(ReplicatedStorage.Shared.Math.Grid)
local Theme = require(script.Parent.Theme)

local BoardTransform = {}
BoardTransform.__index = BoardTransform

export type BoardTransform = typeof(setmetatable(
	{} :: {
		viewport: Frame, -- área disponível (a tela inteira: o HUD flutua por cima)
		window: Frame, -- recorta a cena; ocupa toda a área para a arte sangrar até as bordas
		stage: Frame, -- 16:10 centrado na janela: é a grade de verdade
		world: Frame, -- escala com zoom dentro do palco
		zoom: number,
		offset: Vector2, -- deslocamento em fração do tamanho da janela (0..zoom-1)
		minZoom: number,
		maxZoom: number,
		changed: BindableEvent,
	},
	BoardTransform
))

BoardTransform.MIN_CELL_PIXELS = 36
-- O tabuleiro não ocupa a janela inteira: sobra um respiro em volta para a cena desenhada
-- aparecer e o jogo não dar sensação de aperto. É o "zoom padrão" — o zoom de pinça/roda
-- continua por cima disso.
BoardTransform.BASE_FIT = 0.86

function BoardTransform.new(parent: GuiObject): BoardTransform
	local viewport = Instance.new("Frame")
	viewport.Name = "BoardViewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Parent = parent

	-- Janela: ocupa a área inteira e recorta. Como a arte do mapa é maior que a grade 16:10
	-- (playRect), ela transborda o palco e preenche a tela — o HUD flutua por cima dela.
	local window = Instance.new("Frame")
	window.Name = "BoardWindow"
	window.BackgroundColor3 = Theme.colors.tealDark
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(1, 1)
	window.Parent = viewport

	-- Palco: a grade de verdade, sempre 16:10 e centrada. Todo cálculo de célula, zoom e
	-- deslocamento usa o palco, nunca a janela.
	local stage = Instance.new("Frame")
	stage.Name = "BoardStage"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(BoardTransform.BASE_FIT, BoardTransform.BASE_FIT)
	stage.Parent = window
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = Grid.COLUMNS / Grid.ROWS
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = stage

	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundTransparency = 1
	world.Size = UDim2.fromScale(1, 1)
	world.Position = UDim2.fromScale(0, 0)
	world.Parent = stage

	local self = setmetatable({
		viewport = viewport,
		window = window,
		stage = stage,
		world = world,
		zoom = 1,
		offset = Vector2.zero,
		minZoom = 1,
		maxZoom = 2.6,
		changed = Instance.new("BindableEvent"),
	}, BoardTransform)
	return self
end

function BoardTransform.cellPixels(self: BoardTransform): number
	return self.world.AbsoluteSize.X / Grid.COLUMNS
end

-- Ponto lógico contínuo (unidades de célula) -> posição em escala do mundo
function BoardTransform.logicalToScale(_self: BoardTransform, px: number, py: number): UDim2
	return UDim2.fromScale((px + 0.5) / Grid.COLUMNS, (py + 0.5) / Grid.ROWS)
end

-- Ponto lógico -> pixels de tela (absolutos, sem inset duplicado: o ScreenGui ignora o inset)
function BoardTransform.logicalToScreen(self: BoardTransform, px: number, py: number): Vector2
	local abs = self.world.AbsolutePosition
	local size = self.world.AbsoluteSize
	return Vector2.new(abs.X + (px + 0.5) / Grid.COLUMNS * size.X, abs.Y + (py + 0.5) / Grid.ROWS * size.Y)
end

-- Pixels de tela -> célula (ou nil fora do tabuleiro)
function BoardTransform.screenToCell(self: BoardTransform, screen: Vector2): (number?, number?)
	local abs = self.world.AbsolutePosition
	local size = self.world.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return nil, nil
	end
	local vx = (screen.X - abs.X) / size.X * Grid.VIRTUAL_WIDTH
	local vy = (screen.Y - abs.Y) / size.Y * Grid.VIRTUAL_HEIGHT
	-- também rejeita pontos fora do palco (a área da grade dentro da janela)
	local wabs = self.stage.AbsolutePosition
	local wsize = self.stage.AbsoluteSize
	if screen.X < wabs.X or screen.Y < wabs.Y or screen.X >= wabs.X + wsize.X or screen.Y >= wabs.Y + wsize.Y then
		return nil, nil
	end
	return Grid.virtualToCell(vx, vy)
end

-- Pixels de tela -> ponto lógico contínuo
function BoardTransform.screenToLogical(self: BoardTransform, screen: Vector2): (number, number)
	local abs = self.world.AbsolutePosition
	local size = self.world.AbsoluteSize
	local fx = (screen.X - abs.X) / math.max(size.X, 1)
	local fy = (screen.Y - abs.Y) / math.max(size.Y, 1)
	return fx * Grid.COLUMNS - 0.5, fy * Grid.ROWS - 0.5
end

-- Dentro da área visível da cena (a janela inteira, incluindo a arte que sangra além da grade).
function BoardTransform.isInsideWindow(self: BoardTransform, screen: Vector2): boolean
	local wabs = self.window.AbsolutePosition
	local wsize = self.window.AbsoluteSize
	return screen.X >= wabs.X and screen.Y >= wabs.Y and screen.X < wabs.X + wsize.X and screen.Y < wabs.Y + wsize.Y
end

local function applyTransform(self: BoardTransform, animate: boolean)
	local z = self.zoom
	local maxOffset = math.max(z - 1, 0)
	local ox = math.clamp(self.offset.X, 0, maxOffset)
	local oy = math.clamp(self.offset.Y, 0, maxOffset)
	self.offset = Vector2.new(ox, oy)
	local size = UDim2.fromScale(z, z)
	local pos = UDim2.fromScale(-ox, -oy)
	if animate then
		TweenService:Create(
			self.world,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = size, Position = pos }
		):Play()
	else
		self.world.Size = size
		self.world.Position = pos
	end
	self.changed:Fire()
end

function BoardTransform.setZoom(self: BoardTransform, zoom: number, focusScreen: Vector2?, animate: boolean?)
	local newZoom = math.clamp(zoom, self.minZoom, self.maxZoom)
	if focusScreen then
		-- mantém o ponto sob o foco no mesmo lugar da tela
		local wabs = self.stage.AbsolutePosition
		local wsize = self.stage.AbsoluteSize
		local fx = (focusScreen.X - wabs.X) / math.max(wsize.X, 1)
		local fy = (focusScreen.Y - wabs.Y) / math.max(wsize.Y, 1)
		local worldX = (fx + self.offset.X) / self.zoom
		local worldY = (fy + self.offset.Y) / self.zoom
		self.offset = Vector2.new(worldX * newZoom - fx, worldY * newZoom - fy)
	else
		local cx = (0.5 + self.offset.X) / self.zoom
		local cy = (0.5 + self.offset.Y) / self.zoom
		self.offset = Vector2.new(cx * newZoom - 0.5, cy * newZoom - 0.5)
	end
	self.zoom = newZoom
	applyTransform(self, animate == true)
end

function BoardTransform.pan(self: BoardTransform, deltaScreen: Vector2)
	local wsize = self.stage.AbsoluteSize
	self.offset = self.offset - Vector2.new(deltaScreen.X / math.max(wsize.X, 1), deltaScreen.Y / math.max(wsize.Y, 1))
	applyTransform(self, false)
end

function BoardTransform.reset(self: BoardTransform, animate: boolean?)
	self.zoom = 1
	self.offset = Vector2.zero
	applyTransform(self, animate == true)
end

-- Amplia a região ao redor de uma célula quando as células estão pequenas demais para o toque.
function BoardTransform.zoomToCellIfSmall(self: BoardTransform, x: number, y: number): boolean
	if self:cellPixels() >= BoardTransform.MIN_CELL_PIXELS or self.zoom > 1 then
		return false
	end
	local target = math.min(self.maxZoom, BoardTransform.MIN_CELL_PIXELS * 1.4 / math.max(self:cellPixels(), 1))
	target = math.max(target, 1.6)
	self.zoom = target
	self.offset = Vector2.new((x + 0.5) / Grid.COLUMNS * target - 0.5, (y + 0.5) / Grid.ROWS * target - 0.5)
	applyTransform(self, true)
	return true
end

function BoardTransform.isZoomed(self: BoardTransform): boolean
	return self.zoom > 1.001
end

return BoardTransform
