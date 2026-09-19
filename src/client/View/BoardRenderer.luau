--!strict
-- Apresentação 2D do tabuleiro: chão, caminho, props, Circuitos, sombras, torres, inimigos, efeitos e seleção.
-- Só desenha o estado recebido do servidor. Projéteis e animações são cosméticos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Types)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Localization = require(ReplicatedStorage.Shared.Config.Localization)
local Grid = require(ReplicatedStorage.Shared.Math.Grid)
local Path = require(ReplicatedStorage.Shared.Math.Path)
local Simulation = require(ReplicatedStorage.Shared.Sim.Simulation)
local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Parent.UI.Skin)
local Juice = require(script.Parent.Juice)
local BoardTransform = require(script.Parent.BoardTransform)
local SpritePool = require(script.Parent.SpritePool)
local TowerAnimator = require(script.Parent.TowerAnimator)
local EnemyAnimator = require(script.Parent.EnemyAnimator)
local MatchController = require(script.Parent.Parent.Controllers.MatchController)

local BoardRenderer = {}
BoardRenderer.__index = BoardRenderer

local TOWER_CELLS = 1.6 -- largura do quadro do sprite em células
local ENEMY_CELLS = 1.05
local BOSS_CELLS = 1.9
local PROP_CELLS = 1.5
local BASE_CELLS = 1.9
local MAX_DAMAGE_NUMBERS = 30
local Z =
	{ ground = 1, path = 10, cells = 15, circuits = 20, shadows = 30, entities = 100, effects = 1200, selection = 1300 }

type TowerVisual = {
	container: Frame,
	image: ImageLabel,
	fallback: TextLabel,
	shadow: Frame,
	badge: TextLabel,
	dust: TextLabel,
	animator: TowerAnimator.Animator,
	data: Types.TowerSnapshot,
	depth: number,
}

type EnemyVisual = {
	container: Frame,
	image: ImageLabel,
	fallback: TextLabel,
	shadow: Frame,
	hpBack: Frame,
	hpFill: Frame,
	status: TextLabel,
	resist: TextLabel, -- ícone de resistência física/energia (forma + texto, não só cor)
	badge: TextLabel, -- aviso de habilidade do chefe com contagem
	healMark: TextLabel, -- remendo recebido
	name: TextLabel,
	stroke: UIStroke,
	animator: EnemyAnimator.Animator,
	frameCells: number,
	id: number,
	defId: string,
	isBoss: boolean,
	depth: number,
	dying: boolean,
	healUntil: number,
	px: number,
	py: number,
}

export type Renderer = typeof(setmetatable(
	{} :: {
		transform: BoardTransform.BoardTransform,
		layers: { [string]: Frame },
		mapId: string?,
		path: Path.PathData?,
		towers: { [number]: TowerVisual },
		enemies: { [number]: EnemyVisual },
		enemyPool: SpritePool.SpritePool<EnemyVisual>,
		numberPool: SpritePool.SpritePool<TextLabel>,
		dotPool: SpritePool.SpritePool<Frame>,
		activeNumbers: number,
		circuitLines: { [string]: Frame },
		circuitPulse: { [string]: number },
		selection: Frame?,
		selectionRange: Frame?,
		selectedTowerId: number?,
		previewGhost: Frame?,
		previewRange: Frame?,
		previewLine: Frame?,
		buildCells: { Frame },
		showRanges: boolean,
		showCircuits: boolean,
		damageNumbers: boolean,
		reducedMotion: boolean,
		reducedParticles: boolean,
		circuitPattern: string,
		telegraphRings: { [number]: Frame },
		damageAgg: { [string]: { label: TextLabel, amount: number, at: number } },
		baseCell: Types.Cell?,
		-- Contagem da próxima onda desenhada na entrada do caminho: o jogador olha para onde o
		-- inimigo vai nascer, não para o canto da tela.
		spawnCell: Types.Cell?,
		spawnMarker: Frame?,
		spawnCount: TextLabel?,
		spawnLastSecond: number?,
		spawnPulse: number,
		spawnOffset: number,
		lastSim: number,
	},
	BoardRenderer
))

-- Marca da entrada: discreta enquanto sobra tempo, maior e inquieta nos últimos segundos.
local SPAWN_CALM = 0.95
local SPAWN_URGENT = 1.2
local SPAWN_URGENT_AT = 5

local function cellsToScale(cells: number): UDim2
	return UDim2.fromScale(cells / Grid.COLUMNS, cells / Grid.ROWS)
end

local function layer(parent: Frame, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

function BoardRenderer.new(transform: BoardTransform.BoardTransform): Renderer
	local world = transform.world
	local layers: { [string]: Frame } = {}
	for name, z in pairs(Z) do
		layers[name] = layer(world, name, z)
	end
	local self = setmetatable({
		transform = transform,
		layers = layers,
		mapId = nil,
		path = nil,
		towers = {},
		enemies = {},
		enemyPool = nil :: any,
		numberPool = nil :: any,
		dotPool = nil :: any,
		activeNumbers = 0,
		circuitLines = {},
		circuitPulse = {},
		selection = nil,
		selectionRange = nil,
		selectedTowerId = nil,
		previewGhost = nil,
		previewRange = nil,
		previewLine = nil,
		buildCells = {},
		showRanges = false,
		showCircuits = true,
		damageNumbers = true,
		reducedMotion = false,
		reducedParticles = false,
		circuitPattern = "solid",
		telegraphRings = {},
		damageAgg = {},
		baseCell = nil,
		spawnCell = nil,
		spawnMarker = nil,
		spawnCount = nil,
		spawnLastSecond = nil,
		spawnPulse = 0,
		spawnOffset = -0.85,
		lastSim = 0,
	}, BoardRenderer)

	self.enemyPool = SpritePool.new(function(): EnemyVisual
		return BoardRenderer.createEnemyVisual(self)
	end, function(v: EnemyVisual)
		v.container.Visible = false
		v.shadow.Visible = false
		v.dying = false
		v.image.ImageTransparency = 0
		v.container.Size = cellsToScale(ENEMY_CELLS)
		v.stroke.Enabled = false
		v.resist.Visible = false
		v.badge.Visible = false
		v.healMark.Visible = false
		v.healUntil = 0
		-- cancela feedback antigo: o objeto pode voltar como outra entidade no passo seguinte
		v.animator:restore()
	end)
	self.numberPool = SpritePool.new(function(): TextLabel
		local l = Skin.label(self.layers.effects, "Dmg", "", {
			Size = UDim2.fromScale(1.2 / Grid.COLUMNS, 0.5 / Grid.ROWS),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Theme.fonts.numbers,
			TextSize = 16,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.cream,
			TextStrokeColor3 = Theme.colors.ink,
			TextStrokeTransparency = 0,
			ZIndex = Z.effects + 20,
			Visible = false,
		})
		return l
	end, function(l: TextLabel)
		l.Visible = false
	end)
	self.dotPool = SpritePool.new(function(): Frame
		local d = Skin.frame(self.layers.effects, "Dot", {
			Size = cellsToScale(0.18),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.colors.gold,
			ZIndex = Z.effects + 5,
			Visible = false,
		})
		Skin.corner(d, 999)
		return d
	end, function(d: Frame)
		d.Visible = false
		d.BackgroundTransparency = 0
		d.Size = cellsToScale(0.18)
	end)
	return self
end

-- ---------------------------------------------------------------------------
-- Mapa
-- ---------------------------------------------------------------------------

local function clearChildren(f: Frame)
	for _, c in ipairs(f:GetChildren()) do
		c:Destroy()
	end
end

local function makeImage(parent: Frame, key: string, _cells: number, z: number): (ImageLabel, TextLabel)
	local entry = Assets.get(key)
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.AnchorPoint = Vector2.new(0.5, if entry then entry.anchorY else 0.82)
	image.Position = UDim2.fromScale(0.5, if entry then entry.anchorY else 0.82)
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = z
	image.Image = if entry and entry.image then entry.image :: string else ""
	image.Parent = parent
	local fallback = Skin.label(parent, "Fallback", key, {
		Size = UDim2.fromScale(0.8, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Theme.colors.creamDark,
		Visible = image.Image == "",
		ZIndex = z,
	})
	Skin.corner(fallback, 8)
	Skin.stroke(fallback, Theme.colors.muted, 1)
	return image, fallback
end

-- Textura e quadro do estado. O quadro é o que o animador usa para espelhar a torre.
local function towerImageFrame(defId: string, state: string): (string, number, number)
	local entry = Assets.get(Assets.towerKey(defId, state))
	if not entry then
		return "", 128, 128
	end
	return (entry.image or "") :: string, entry.width, entry.height
end

function BoardRenderer.setMap(self: Renderer, mapId: string)
	self.mapId = mapId
	self.path = Simulation.getPath(mapId)
	local map = Catalog.getMap(mapId)
	assert(map, "mapa desconhecido")
	for _, f in pairs(self.layers) do
		clearChildren(f)
	end
	self.towers = {}
	self.enemies = {}
	self.circuitLines = {}
	self.telegraphRings = {}
	self.buildCells = {}
	self.enemyPool = SpritePool.new(self.enemyPool.factory, self.enemyPool.reset)
	self.numberPool = SpritePool.new(self.numberPool.factory, self.numberPool.reset)
	self.dotPool = SpritePool.new(self.dotPool.factory, self.dotPool.reset)
	self.activeNumbers = 0
	self.damageAgg = {}

	-- chão com fundo sólido por baixo da margem transparente
	local groundEntry = Assets.get(Assets.groundKey(mapId))
	local backing = Skin.frame(self.layers.ground, "Backing", { Size = UDim2.fromScale(1, 1), ZIndex = Z.ground })
	if groundEntry and groundEntry.backingColor then
		local c = groundEntry.backingColor
		backing.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
	else
		backing.BackgroundColor3 = Theme.colors.tealDark
	end
	-- Cena inteira: a arte traz grama, caminho, cenário e base juntos. playRect diz que fração
	-- da imagem é a grade 16x10, então a imagem é posicionada para encaixar célula com célula.
	local scene = if groundEntry then groundEntry.playRect else nil
	local ground = Instance.new("ImageLabel")
	ground.Name = "Ground"
	ground.BackgroundTransparency = 1
	ground.ScaleType = Enum.ScaleType.Stretch
	ground.Image = if groundEntry and groundEntry.image then groundEntry.image :: string else ""
	ground.ZIndex = Z.ground + 1
	if scene then
		local rect = scene :: { number }
		local fractionX = math.max(rect[3] - rect[1], 0.01)
		local fractionY = math.max(rect[4] - rect[2], 0.01)
		ground.Size = UDim2.fromScale(1 / fractionX, 1 / fractionY)
		ground.Position = UDim2.fromScale(-rect[1] / fractionX, -rect[2] / fractionY)
	else
		ground.Size = UDim2.fromScale(1, 1)
	end
	ground.Parent = self.layers.ground
	self.transform.window.BackgroundColor3 = backing.BackgroundColor3

	-- Numa janela bem mais larga que 16:10 a arte alinhada não alcança as bordas. Em vez de
	-- deixar aparecer a cor de fundo, a mesma imagem entra atrás, recortada para cobrir: as
	-- bordas continuam sendo o quintal, e a arte alinhada por cima é que manda na grade.
	local previousBackdrop = self.transform.window:FindFirstChild("SceneBackdrop")
	if previousBackdrop then
		previousBackdrop:Destroy()
	end
	if scene and groundEntry and groundEntry.image then
		local backdrop = Instance.new("ImageLabel")
		backdrop.Name = "SceneBackdrop"
		backdrop.BackgroundTransparency = 1
		backdrop.BorderSizePixel = 0
		backdrop.Image = groundEntry.image :: string
		backdrop.ScaleType = Enum.ScaleType.Crop
		backdrop.ImageColor3 = Color3.fromRGB(150, 155, 145) -- um tom abaixo: a borda não disputa com a grade
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.Active = false
		backdrop.ZIndex = 0
		backdrop.Parent = self.transform.window
	end
	local artHasPath = groundEntry ~= nil and groundEntry.includesPath == true
	local artHasBase = groundEntry ~= nil and groundEntry.includesBase == true

	-- Luz do alto: clareia o topo do terreno e escurece a base, como na direção de arte.
	local sun = Instance.new("UIGradient")
	sun.Rotation = 90
	sun.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(198, 205, 190))
	sun.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	sun.Parent = ground

	-- Xadrez discreto: ajuda a contar células sem desenhar uma grade dura por cima da arte.
	-- A cena desenhada já tem os quadrados pintados, então ele só entra no chão antigo.
	local tiles = Skin.frame(self.layers.ground, "Tiles", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Z.ground + 2,
	})
	for x = 0, Grid.COLUMNS - 1 do
		for y = 0, Grid.ROWS - 1 do
			if (x + y) % 2 == 0 and not artHasPath then
				local tile = Skin.frame(tiles, "T", {
					Size = cellsToScale(1),
					Position = self.transform:logicalToScale(x, y),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Theme.colors.white,
					BackgroundTransparency = 0.94,
					ZIndex = Z.ground + 2,
				})
				Skin.corner(tile, 4)
			end
		end
	end

	-- Vinheta interna só no chão antigo: a cena desenhada já traz folhagem nas bordas.
	if not scene then
		Skin.vignette(self.layers.ground, 0.32).ZIndex = Z.ground + 3
	end

	-- caminho a partir dos dados canônicos (a cena desenhada já traz o seu)
	local colors = Theme.pathColors[mapId] or Theme.pathColors.jardim
	for _, cell in ipairs(if artHasPath then {} else map.pathCells) do
		-- sombra curta sob a trilha: a terra batida fica "afundada" no gramado
		local shade = Skin.frame(self.layers.path, "PathShade", {
			Size = cellsToScale(1.22),
			Position = self.transform:logicalToScale(cell[1], cell[2] + 0.06),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.colors.inkDeep,
			BackgroundTransparency = 0.82,
			ZIndex = Z.path - 1,
		})
		Skin.corner(shade, 12)
		local outline = Skin.frame(self.layers.path, "PathOutline", {
			Size = cellsToScale(1.16),
			Position = self.transform:logicalToScale(cell[1], cell[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = colors[2],
			ZIndex = Z.path,
		})
		Skin.corner(outline, 10)
		local fill = Skin.frame(self.layers.path, "PathFill", {
			Size = cellsToScale(1.0),
			Position = self.transform:logicalToScale(cell[1], cell[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = colors[1],
			ZIndex = Z.path + 1,
		})
		Skin.corner(fill, 8)
	end
	-- setas nas curvas e na entrada
	for i = 1, (if artHasPath then 0 else #map.path - 1) do
		local a, b = map.path[i], map.path[i + 1]
		local dx, dy = math.sign(b[1] - a[1]), math.sign(b[2] - a[2])
		local angle = if dx == 1 then 0 elseif dx == -1 then 180 elseif dy == 1 then 90 else -90
		local arrow = Skin.label(self.layers.path, "Arrow", "➜", {
			Size = cellsToScale(0.6),
			Position = self.transform:logicalToScale(a[1], a[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = colors[2],
			Rotation = angle,
			ZIndex = Z.path + 2,
		})
		arrow.Font = Theme.fonts.bodyBold
	end
	local entry = map.path[1]
	Skin.label(self.layers.path, "Entrada", if artHasPath then "" else "▶", {
		Size = cellsToScale(0.5),
		Position = self.transform:logicalToScale(entry[1] - 0.55, entry[2]),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextColor3 = Theme.colors.cream,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.colors.ink,
		ZIndex = Z.path + 3,
	})

	-- props nas células bloqueadas
	local propKeys: { string } = {}
	for key, e in pairs(Assets.entries) do
		if e.kind == "prop" and key:find("prop_" .. mapId) then
			table.insert(propKeys, key)
		end
	end
	table.sort(propKeys)
	for i, cell in ipairs(if artHasPath then {} else map.blocked) do
		local key = propKeys[((i - 1) % math.max(#propKeys, 1)) + 1]
		if key then
			local holder = Skin.frame(self.layers.shadows, "Prop", {
				Size = cellsToScale(PROP_CELLS),
				Position = self.transform:logicalToScale(cell[1], cell[2] + 0.1),
				AnchorPoint = Vector2.new(0.5, 0.82),
				BackgroundTransparency = 1,
				ZIndex = Z.shadows + 2,
			})
			makeImage(holder, key, PROP_CELLS, Z.shadows + 2)
		end
	end
	-- Farol de Pilha na saída
	local last = map.path[#map.path]
	self.baseCell = last
	local baseCells: { Types.Cell } = if artHasBase then {} else { last }
	local glow = Skin.frame(self.layers.shadows, "BaseGlow", {
		Size = cellsToScale(3.4),
		Position = self.transform:logicalToScale(last[1], last[2]),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.glowWarm,
		BackgroundTransparency = 0.86,
		ZIndex = Z.shadows + 1,
	})
	Skin.corner(glow, 9999)
	glow.Visible = not artHasBase
	-- Marca da entrada: um "!" com a contagem, na célula onde a onda nasce.
	local spawn = map.path[1]
	self.spawnCell = spawn
	-- a bolha fica quase em cima da célula de entrada: mais alta que isso ela esbarra nas
	-- fichas do HUD quando a entrada está nas primeiras linhas
	local markerOffset = if spawn[2] <= 0 then 0.5 else -0.45
	self.spawnOffset = markerOffset
	local marker = Skin.frame(self.layers.effects, "SpawnMarker", {
		Size = cellsToScale(SPAWN_CALM),
		Position = self.transform:logicalToScale(spawn[1], spawn[2] + markerOffset),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = Z.effects + 6,
	})
	marker.Visible = false
	local bubble = Skin.frame(marker, "Bubble", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.cream,
		ZIndex = Z.effects + 6,
	})
	Skin.corner(bubble, 999)
	Skin.stroke(bubble, Theme.colors.ink, 3)
	local count = Skin.label(bubble, "Count", "!", {
		-- menor que a bolha (com TextScaled em 100% o número encosta no contorno) e centrado
		-- nos dois eixos: o padrão do Skin.label é alinhado à esquerda
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		Font = Theme.fonts.numbers,
		TextColor3 = Theme.colors.ink,
		TextScaled = true,
		ZIndex = Z.effects + 7,
	})
	self.spawnMarker = marker
	self.spawnCount = count
	self.spawnLastSecond = nil

	for _, baseCell in ipairs(baseCells) do
		local baseHolder = Skin.frame(self.layers.entities, "Base", {
			Size = cellsToScale(BASE_CELLS),
			Position = self.transform:logicalToScale(baseCell[1], baseCell[2] + 0.15),
			AnchorPoint = Vector2.new(0.5, 0.82),
			BackgroundTransparency = 1,
			ZIndex = Z.entities + math.floor((baseCell[2] + 0.15) * 100) + 5,
		})
		makeImage(baseHolder, "base_farol_pilha", BASE_CELLS, baseHolder.ZIndex)
	end
end

-- ---------------------------------------------------------------------------
-- Torres
-- ---------------------------------------------------------------------------

local function ownerBadgeText(userId: number): (string, Color3)
	local idx = MatchController.participantColor(userId)
	local o = Theme.owners[idx] or Theme.owners[1]
	return o.glyph, o.color
end

function BoardRenderer.createTowerVisual(self: Renderer, data: Types.TowerSnapshot): TowerVisual
	local key = Assets.towerKey(data.d, data.st)
	local depth = Z.entities + math.floor(data.y * 100)
	local container = Skin.frame(self.layers.entities, "Tower_" .. data.id, {
		Size = cellsToScale(TOWER_CELLS),
		Position = self.transform:logicalToScale(data.x, data.y),
		AnchorPoint = Vector2.new(0.5, 0.82),
		BackgroundTransparency = 1,
		ZIndex = depth,
	})
	local image, fallback = makeImage(container, key, TOWER_CELLS, depth)
	if image.Image == "" then
		fallback.Text = Theme.towerGlyphs[data.d] .. " " .. data.st
		fallback.BackgroundColor3 = Theme.towerColors[data.d] or Theme.colors.creamDark
	end
	local shadow = Skin.frame(self.layers.shadows, "Shadow_" .. data.id, {
		Size = UDim2.fromScale(0.72 / Grid.COLUMNS, 0.22 / Grid.ROWS),
		Position = self.transform:logicalToScale(data.x, data.y + 0.02),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.78,
		ZIndex = Z.shadows,
	})
	Skin.corner(shadow, 999)
	local glyph, color = ownerBadgeText(data.o)
	local badge = Skin.label(container, "Badge", glyph, {
		Size = UDim2.fromScale(0.22, 0.22),
		Position = UDim2.fromScale(0.86, 0.72),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.ink,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		ZIndex = depth + 1,
		Visible = false,
	})
	Skin.corner(badge, 999)
	Skin.stroke(badge, Theme.colors.ink, 1)
	local dust = Skin.label(container, "Dust", "≋", {
		Size = UDim2.fromScale(0.3, 0.3),
		Position = UDim2.fromScale(0.5, 0.05),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.muted,
		Visible = false,
		ZIndex = depth + 1,
	})
	local entryAsset = Assets.get(key)
	local animator = TowerAnimator.new(
		image,
		data.d,
		if entryAsset then entryAsset.anchorY else 0.82,
		if entryAsset then entryAsset.width else nil,
		if entryAsset then entryAsset.height else nil
	)
	animator:setImage(towerImageFrame(data.d, data.st))
	-- a torre nasce com um salto curto e um anel de poeira na célula
	Juice.pop(container, 0.82)
	Juice.ring(
		self.layers.effects,
		self.transform:logicalToScale(data.x, data.y),
		0.4 / Grid.COLUMNS,
		1.6 / Grid.COLUMNS,
		Theme.towerColors[data.d] or Theme.colors.gold
	)
	return {
		container = container,
		image = image,
		fallback = fallback,
		shadow = shadow,
		badge = badge,
		dust = dust,
		animator = animator,
		data = data,
		depth = depth,
	}
end

local function towerImageFor(defId: string, state: string): (string, string)
	local key = Assets.towerKey(defId, state)
	local entry = Assets.get(key)
	return if entry and entry.image then entry.image :: string else "", key
end

function BoardRenderer.syncTowers(self: Renderer, towers: { [number]: Types.TowerSnapshot }, participantsCount: number)
	for id, data in pairs(towers) do
		local visual: TowerVisual? = self.towers[id]
		if visual == nil then
			local created = BoardRenderer.createTowerVisual(self, data)
			self.towers[id] = created
			created.animator:playBuild()
			visual = created
		else
			if visual.data.st ~= data.st then
				local img, frameWidth, frameHeight = towerImageFrame(data.d, data.st)
				if img ~= "" then
					visual.animator:playUpgrade(img, frameWidth, frameHeight)
					visual.fallback.Visible = false
				else
					visual.fallback.Text = Theme.towerGlyphs[data.d] .. " " .. data.st
					visual.fallback.Visible = true
				end
				BoardRenderer.playLevelUp(self, data.x, data.y, data.st)
			end
			visual.data = data
		end
		local v = visual :: TowerVisual
		v.badge.Visible = participantsCount > 1
		local glyph, color = ownerBadgeText(data.o)
		v.badge.Text = glyph
		v.badge.BackgroundColor3 = color
	end
	for id, visual in pairs(self.towers) do
		if not towers[id] then
			visual.animator:destroy()
			visual.container:Destroy()
			visual.shadow:Destroy()
			self.towers[id] = nil
			if self.selectedTowerId == id then
				BoardRenderer.setSelected(self, nil)
			end
		end
	end
	BoardRenderer.syncCircuits(self, towers)
end

-- ---------------------------------------------------------------------------
-- Circuitos
-- ---------------------------------------------------------------------------

function BoardRenderer.syncCircuits(self: Renderer, towers: { [number]: Types.TowerSnapshot })
	local wanted: { [string]: { a: Types.TowerSnapshot, b: Types.TowerSnapshot, id: string } } = {}
	for id, t in pairs(towers) do
		local partner = t.cp
		if partner and t.ci and id < partner then
			local other = towers[partner]
			if other then
				wanted[id .. "-" .. partner] = { a = t, b = other, id = t.ci :: string }
			end
		end
	end
	for key, line in pairs(self.circuitLines) do
		if not wanted[key] then
			line:Destroy()
			self.circuitLines[key] = nil
		end
	end
	for key, pair in pairs(wanted) do
		if not self.circuitLines[key] then
			local a, b = pair.a, pair.b
			local horizontal = a.y == b.y
			local mx, my = (a.x + b.x) / 2, (a.y + b.y) / 2
			local line = Skin.frame(self.layers.circuits, "Circuit_" .. key, {
				Size = if horizontal
					then UDim2.fromScale(1 / Grid.COLUMNS, 0.09 / Grid.ROWS)
					else UDim2.fromScale(0.09 / Grid.COLUMNS, 1 / Grid.ROWS),
				Position = self.transform:logicalToScale(mx, my + 0.05),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.colors.cyan,
				ZIndex = Z.circuits,
			})
			Skin.corner(line, 999)
			Skin.stroke(line, Theme.colors.ink, 1)
			for _, t in ipairs({ a, b }) do
				local dot = Skin.frame(line, "End", {
					Size = if horizontal then UDim2.fromScale(0.2, 2.6) else UDim2.fromScale(2.6, 0.2),
					Position = if t == a
						then (if horizontal then UDim2.fromScale(0.05, 0.5) else UDim2.fromScale(0.5, 0.05))
						else (if horizontal then UDim2.fromScale(0.95, 0.5) else UDim2.fromScale(0.5, 0.95)),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Theme.colors.cyan,
					ZIndex = Z.circuits + 1,
				})
				Skin.corner(dot, 999)
				Skin.stroke(dot, Theme.colors.ink, 1)
			end
			if self.circuitPattern == "dashed" then
				for i = 1, 3 do
					local gap = Skin.frame(line, "Gap", {
						Size = if horizontal then UDim2.fromScale(0.08, 1.2) else UDim2.fromScale(1.2, 0.08),
						Position = if horizontal
							then UDim2.fromScale(0.2 + 0.2 * i, 0.5)
							else UDim2.fromScale(0.5, 0.2 + 0.2 * i),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Theme.colors.ink,
						ZIndex = Z.circuits + 2,
					})
					gap.Name = "Gap"
				end
			end
			line.Visible = self.showCircuits
			self.circuitLines[key] = line
			self.circuitPulse[key] = os.clock()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Inimigos
-- ---------------------------------------------------------------------------

function BoardRenderer.createEnemyVisual(self: Renderer): EnemyVisual
	local container = Skin.frame(self.layers.entities, "Enemy", {
		Size = cellsToScale(ENEMY_CELLS),
		AnchorPoint = Vector2.new(0.5, 0.82),
		BackgroundTransparency = 1,
		ZIndex = Z.entities,
		Visible = false,
	})
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.AnchorPoint = Vector2.new(0.5, 0.82)
	image.Position = UDim2.fromScale(0.5, 0.82)
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = Z.entities
	image.Parent = container
	local stroke = Skin.stroke(image, Theme.colors.gold, 3)
	stroke.Enabled = false
	local fallback = Skin.label(container, "Fallback", "?", {
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = Theme.colors.enemy,
		BackgroundTransparency = 0,
		TextColor3 = Theme.colors.cream,
		Visible = false,
		ZIndex = Z.entities,
	})
	Skin.corner(fallback, 999)
	Skin.stroke(fallback, Theme.colors.ink, 2)
	local shadow = Skin.frame(self.layers.shadows, "EnemyShadow", {
		Size = UDim2.fromScale(0.55 / Grid.COLUMNS, 0.18 / Grid.ROWS),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.8,
		ZIndex = Z.shadows + 1,
		Visible = false,
	})
	Skin.corner(shadow, 999)
	local hpBack = Skin.frame(container, "HpBack", {
		Size = UDim2.fromScale(0.8, 0.07),
		Position = UDim2.fromScale(0.5, 0.06),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.ink,
		ZIndex = Z.entities + 2,
	})
	Skin.corner(hpBack, 999)
	local hpFill = Skin.frame(hpBack, "HpFill", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.coral,
		ZIndex = Z.entities + 3,
	})
	Skin.corner(hpFill, 999)
	local status = Skin.label(container, "Status", "", {
		Size = UDim2.fromScale(1, 0.18),
		Position = UDim2.fromScale(0.5, -0.06),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.cyan,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.colors.ink,
		ZIndex = Z.entities + 3,
	})
	local name = Skin.label(container, "Name", "", {
		Size = UDim2.fromScale(1.6, 0.16),
		Position = UDim2.fromScale(0.5, -0.2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.cream,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.colors.ink,
		Font = Theme.fonts.title,
		Visible = false,
		ZIndex = Z.entities + 3,
	})
	-- resistência: ícone com forma própria à esquerda da barra (nunca só cor)
	local resist = Skin.label(container, "Resist", "", {
		Size = UDim2.fromScale(0.26, 0.16),
		Position = UDim2.fromScale(0.05, 0.06),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.cream,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.colors.ink,
		Visible = false,
		ZIndex = Z.entities + 4,
	})
	-- aviso do chefe com contagem em segundos de simulação
	local badge = Skin.label(container, "Badge", "", {
		Size = UDim2.fromScale(0.9, 0.18),
		Position = UDim2.fromScale(0.5, -0.12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.danger,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.colors.ink,
		Font = Theme.fonts.title,
		Visible = false,
		ZIndex = Z.entities + 5,
	})
	local healMark = Skin.label(container, "Heal", "✚", {
		Size = UDim2.fromScale(0.3, 0.2),
		Position = UDim2.fromScale(0.85, 0.1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.teal,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.colors.ink,
		Visible = false,
		ZIndex = Z.entities + 5,
	})
	return {
		container = container,
		image = image,
		fallback = fallback,
		shadow = shadow,
		hpBack = hpBack,
		hpFill = hpFill,
		status = status,
		resist = resist,
		badge = badge,
		healMark = healMark,
		name = name,
		stroke = stroke,
		animator = EnemyAnimator.new(image, "fiapo", 0, 0.82, 1),
		frameCells = ENEMY_CELLS,
		id = 0,
		defId = "",
		isBoss = false,
		depth = 0,
		dying = false,
		healUntil = 0,
		px = 0,
		py = 0,
	}
end

local function enemyDisplayName(defId: string): string
	return Localization.get("enemy." .. defId)
end

-- Aviso de cada chefe: poeira (Aspirador), escudo (Rei Ferrugem), estrela (Breu).
local BOSS_BADGE: { [string]: string } = { aspirador = "≋", rei_ferrugem = "⛨", breu = "★" }

local function bossBadgeIcon(defId: string): string
	return BOSS_BADGE[defId] or "!"
end

-- Filhos do Casulo reusam o sprite de Fiapo em 70% da escala (enemy_visuals.json, spawnedVariants);
-- os Corriscos invocados por Breu usam a escala normal. O tamanho não altera atributos.
local function visualScaleFor(ev: MatchController.EnemyView): number
	if ev.isSummon and ev.defId == "fiapo" then
		return 0.7
	end
	return 1
end

-- Ícone de resistência do tipo (formato + letra, legível sem depender de cor).
local function resistIconFor(defId: string, isBoss: boolean): (string, Color3?)
	local def = if isBoss then nil else Catalog.getEnemy(defId)
	if def then
		if (def.energyResistance or 0) > 0 then
			return "◈", Theme.colors.cyan
		end
		if def.armor > 0 then
			return "⛨", Theme.colors.sand
		end
		if def.healPulse then
			return "✚", Theme.colors.teal
		end
		if def.splitOnDeath then
			return "❖", Theme.colors.gold
		end
	end
	return "", nil
end

function BoardRenderer.acquireEnemy(self: Renderer, ev: MatchController.EnemyView): EnemyVisual
	local visual = self.enemyPool:acquire()
	visual.id = ev.id
	visual.defId = ev.defId
	visual.isBoss = ev.isBoss
	visual.dying = false
	visual.healUntil = 0
	local key = Assets.enemyKey(ev.defId, ev.isBoss)
	local entry = Assets.get(key)
	visual.image.Image = if entry and entry.image then entry.image :: string else ""
	visual.fallback.Visible = visual.image.Image == ""
	visual.fallback.Text = ev.defId:sub(1, 2):upper()
	-- largura do quadro por tipo: vem do export normalizado para que a largura visível em células
	-- corresponda ao guia. Sem entrada (arte ainda não exportada) usa o tamanho genérico.
	local scale = visualScaleFor(ev)
	local baseCells = if entry and entry.frameWidthCells
		then entry.frameWidthCells :: number
		else (if ev.isBoss then BOSS_CELLS else ENEMY_CELLS)
	local cells = baseCells * scale
	visual.frameCells = cells
	visual.container.Size = cellsToScale(cells)
	local anchorY = if entry then entry.anchorY else 0.82
	visual.container.AnchorPoint = Vector2.new(if entry then entry.anchorX else 0.5, anchorY)
	visual.image.AnchorPoint = Vector2.new(0.5, anchorY)
	visual.image.ImageTransparency = 0
	visual.animator:reset(ev.defId, ev.id, anchorY, 1)
	visual.name.Visible = ev.isBoss
	visual.name.Text = if ev.isBoss then enemyDisplayName(ev.defId) else ""
	local icon, color = resistIconFor(ev.defId, ev.isBoss)
	visual.resist.Text = icon
	visual.resist.Visible = icon ~= ""
	if color then
		visual.resist.TextColor3 = color
	end
	visual.badge.Visible = false
	visual.healMark.Visible = false
	visual.hpBack.Visible = true
	visual.container.Visible = true
	visual.shadow.Visible = true
	visual.shadow.Size = UDim2.fromScale(0.55 * scale / Grid.COLUMNS, 0.18 * scale / Grid.ROWS)
	visual.container.Name = "Enemy_" .. ev.id
	self.enemies[ev.id] = visual
	return visual
end

function BoardRenderer.releaseEnemy(self: Renderer, id: number)
	local visual = self.enemies[id]
	if visual then
		self.enemies[id] = nil
		self.enemyPool:release(visual)
	end
end

-- Morte cosmética: poeira se dissolve; leak: some rapidamente na base.
function BoardRenderer.playEnemyExit(self: Renderer, id: number, kind: "death" | "leak")
	local visual = self.enemies[id]
	if not visual or visual.dying then
		return
	end
	visual.dying = true
	self.enemies[id] = nil
	visual.badge.Visible = false
	visual.healMark.Visible = false
	BoardRenderer.setTelegraph(self, id, nil, nil, false)
	local duration = if kind == "death" then 0.3 else 0.12
	if self.reducedMotion then
		duration = 0.08
	end
	if kind == "death" and visual.defId == "casulo" then
		visual.animator:playDeathShake()
	end
	local tween =
		TweenService:Create(visual.image, TweenInfo.new(duration, Enum.EasingStyle.Quad), { ImageTransparency = 1 })
	tween:Play()
	if kind == "death" and not self.reducedParticles then
		-- estouro em leque + anel curto: a morte precisa ser lida de relance no meio da onda
		local position = self.transform:logicalToScale(visual.px, visual.py - 0.25)
		Juice.burst(self.layers.effects, position, {
			count = if visual.isBoss then 14 else 7,
			color = if visual.isBoss then Theme.colors.gold else Theme.colors.enemy,
			spread = if visual.isBoss then 0.06 else 0.035,
			size = 0.01,
		})
		Juice.ring(
			self.layers.effects,
			position,
			0.3 / Grid.COLUMNS,
			(if visual.isBoss then 3.2 else 1.4) / Grid.COLUMNS,
			if visual.isBoss then Theme.colors.gold else Theme.colors.enemy
		)
	end
	tween.Completed:Once(function()
		visual.image.ImageTransparency = 0
		self.enemyPool:release(visual)
	end)
end

-- Impacto confirmado pelo servidor: escurecimento curto de 0,12 s.
function BoardRenderer.playEnemyHit(self: Renderer, enemyId: number)
	local visual = self.enemies[enemyId]
	if visual and not visual.dying then
		visual.animator:playHit()
		Juice.hitFlash(visual.image)
	end
end

-- Entrada dos invocados (Breu): escala curta; a entidade já existe e já pode ser atacada.
function BoardRenderer.playEnemySpawnIn(self: Renderer, enemyId: number)
	local visual = self.enemies[enemyId]
	if visual and not visual.dying then
		visual.animator:playSpawnIn()
	end
end

-- ---------------------------------------------------------------------------
-- Efeitos
-- ---------------------------------------------------------------------------

local function ringFrame(
	self: Renderer,
	px: number,
	py: number,
	radiusCells: number,
	color: Color3,
	thickness: number,
	z: number
): Frame
	local ring = Skin.frame(self.layers.effects, "Ring", {
		Size = cellsToScale(radiusCells * 2),
		Position = self.transform:logicalToScale(px, py),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = z,
	})
	Skin.corner(ring, 999)
	Skin.stroke(ring, color, thickness)
	return ring
end

function BoardRenderer.enemyPosition(self: Renderer, id: number): (number?, number?)
	local visual = self.enemies[id]
	if visual then
		return visual.px, visual.py
	end
	return nil, nil
end

function BoardRenderer.playAttack(self: Renderer, towerId: number, seq: number, targets: { Types.AttackTarget })
	local visual = self.towers[towerId]
	if not visual then
		return
	end
	local def = Catalog.getTower(visual.data.d)
	local tx, ty = visual.data.x, visual.data.y
	local firstTarget = targets[1]
	local fx: number? = nil
	local fy: number? = nil
	if firstTarget then
		fx, fy = BoardRenderer.enemyPosition(self, firstTarget.enemyId)
	end
	visual.animator:playAction(seq, if fx then fx - tx else nil)
	if self.reducedParticles or not def then
		return
	end
	local color = Theme.towerColors[visual.data.d] or Theme.colors.gold
	if def.damageType == "none" then
		-- pulso de apoio discreto
		local ring = ringFrame(self, tx, ty, 0.3, Theme.colors.coral, 2, Z.effects)
		local stats = Catalog.getStateStats(visual.data.d, visual.data.st)
		local range = if stats then stats.range else 2
		local t = TweenService:Create(
			ring,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = cellsToScale(range * 2) }
		)
		t:Play()
		local stroke = ring:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		t.Completed:Once(function()
			ring:Destroy()
		end)
		return
	end
	if visual.data.d == "voltz" then
		-- corrente: linhas finas entre alvos sucessivos
		local prevX, prevY = tx, ty - 0.5
		for _, target in ipairs(targets) do
			local ex, ey = BoardRenderer.enemyPosition(self, target.enemyId)
			if ex and ey then
				local dx, dy = ex - prevX, (ey - 0.3) - prevY
				local length = math.sqrt(dx * dx + dy * dy)
				local line = Skin.frame(self.layers.effects, "Chain", {
					Size = UDim2.fromScale(length / Grid.COLUMNS, 0.08 / Grid.ROWS),
					Position = self.transform:logicalToScale((prevX + ex) / 2, (prevY + ey - 0.3) / 2),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Theme.colors.cyan,
					Rotation = math.deg(math.atan2(dy, dx)),
					ZIndex = Z.effects + 3,
				})
				task.delay(0.15, function()
					line:Destroy()
				end)
				prevX, prevY = ex, ey - 0.3
			end
		end
		return
	end
	-- projétil breve até o alvo primário
	if fx ~= nil and fy ~= nil then
		local ex: number = fx
		local ey: number = fy
		local dot = self.dotPool:acquire()
		dot.BackgroundColor3 = color
		dot.Size = if visual.data.d == "pipoca" then cellsToScale(0.28) else cellsToScale(0.16)
		dot.Position = self.transform:logicalToScale(tx, ty - 0.6)
		dot.Visible = true
		local duration = if self.reducedMotion then 0.05 else 0.14
		local tween = TweenService:Create(
			dot,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Position = self.transform:logicalToScale(ex, ey - 0.35) }
		)
		tween:Play()
		tween.Completed:Once(function()
			self.dotPool:release(dot)
			local stats = Catalog.getStateStats(visual.data.d, visual.data.st)
			if stats and stats.splash then
				local ring = ringFrame(self, ex, ey - 0.2, 0.2, color, 3, Z.effects + 1)
				local t = TweenService:Create(
					ring,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = cellsToScale(stats.splash * 2) }
				)
				t:Play()
				local stroke = ring:FindFirstChildOfClass("UIStroke")
				if stroke then
					TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 1 }):Play()
				end
				t.Completed:Once(function()
					ring:Destroy()
				end)
			else
				local ring = ringFrame(self, ex, ey - 0.3, 0.1, color, 2, Z.effects + 1)
				local t = TweenService:Create(
					ring,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = cellsToScale(0.6) }
				)
				t:Play()
				t.Completed:Once(function()
					ring:Destroy()
				end)
			end
		end)
	end
end

function BoardRenderer.showDamage(self: Renderer, towerId: number, enemyId: number, amount: number, isPulse: boolean)
	if not self.damageNumbers then
		return
	end
	local px, py = BoardRenderer.enemyPosition(self, enemyId)
	if not px or not py then
		return
	end
	local key = towerId .. ":" .. enemyId
	local agg = self.damageAgg[key]
	local now = os.clock()
	if agg and now - agg.at < 0.3 and agg.label.Visible then
		agg.amount += amount
		agg.label.Text = tostring(math.floor(agg.amount + 0.5))
		return
	end
	if self.activeNumbers >= MAX_DAMAGE_NUMBERS then
		return
	end
	local label = self.numberPool:acquire()
	self.activeNumbers += 1
	label.Text = tostring(math.floor(amount + 0.5))
	label.TextColor3 = if isPulse then Theme.colors.cyan else Theme.colors.cream
	label.Position = self.transform:logicalToScale(px, py - 0.7)
	label.TextTransparency = 0
	label.Visible = true
	self.damageAgg[key] = { label = label, amount = amount, at = now }
	-- sobe em arco com um salto curto de tamanho (juice_float): leitura rápida do dano
	local rise = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = self.transform:logicalToScale(px + (math.random() - 0.5) * 0.35, py - 1.35),
		TextTransparency = 1,
	})
	label.Size = UDim2.fromScale(0.9 / Grid.COLUMNS, 0.38 / Grid.ROWS)
	if not self.reducedMotion then
		TweenService:Create(label, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1.4 / Grid.COLUMNS, 0.6 / Grid.ROWS),
		}):Play()
	end
	rise:Play()
	rise.Completed:Once(function()
		self.activeNumbers -= 1
		self.numberPool:release(label)
		if self.damageAgg[key] and self.damageAgg[key].label == label then
			self.damageAgg[key] = nil
		end
	end)
end

-- Contagem para a próxima onda, desenhada na entrada do caminho. Chamada todo quadro.
function BoardRenderer.updateSpawnCountdown(self: Renderer, secondsLeft: number?, dt: number)
	local marker = self.spawnMarker
	local count = self.spawnCount
	if not marker or not count then
		return
	end
	if secondsLeft == nil then
		if marker.Visible then
			marker.Visible = false
			self.spawnLastSecond = nil
		end
		return
	end
	marker.Visible = true
	local whole = math.max(0, math.ceil(secondsLeft))
	local urgent = whole <= SPAWN_URGENT_AT
	if whole ~= self.spawnLastSecond then
		self.spawnLastSecond = whole
		-- o salto a cada segundo só existe na reta final; antes disso a marca fica quieta
		self.spawnPulse = if urgent then 1 else 0
	end
	count.Text = if whole > 0 then tostring(whole) else "!"
	local bubble = marker:FindFirstChild("Bubble")
	if bubble and bubble:IsA("Frame") then
		bubble.BackgroundColor3 = if urgent then Theme.colors.dangerSoft else Theme.colors.cream
		local stroke = bubble:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if urgent then Theme.colors.danger else Theme.colors.ink
		end
	end
	count.TextColor3 = if urgent then Theme.colors.danger else Theme.colors.ink
	local base = if urgent then SPAWN_URGENT else SPAWN_CALM
	local spawn = self.spawnCell
	if self.reducedMotion or not urgent then
		marker.Size = cellsToScale(base)
		marker.Rotation = 0
		if spawn then
			marker.Position = self.transform:logicalToScale(spawn[1], spawn[2] + self.spawnOffset)
		end
		return
	end
	self.spawnPulse = math.max(self.spawnPulse - dt * 3.2, 0)
	local pop = 1 + 0.3 * self.spawnPulse * self.spawnPulse
	marker.Size = cellsToScale(base * pop)
	if spawn then
		local shake = math.sin(os.clock() * 26) * 0.05
		marker.Position = self.transform:logicalToScale(spawn[1] + shake, spawn[2] + self.spawnOffset)
		marker.Rotation = math.sin(os.clock() * 22) * 5
	end
end

-- Verdadeiro quando o ponto da tela caiu na marca da entrada (ela é alvo de clique: chamar a
-- onda mais cedo). Teste por retângulo porque a marca é desenhada no mundo, não no HUD.
function BoardRenderer.spawnMarkerHit(self: Renderer, screen: Vector2): boolean
	local marker = self.spawnMarker
	if not marker or not marker.Visible then
		return false
	end
	local pos = marker.AbsolutePosition
	local size = marker.AbsoluteSize
	return screen.X >= pos.X and screen.Y >= pos.Y and screen.X <= pos.X + size.X and screen.Y <= pos.Y + size.Y
end

-- Onda começou: a marca vira um estouro na entrada. Com bônus por adiantar, o estouro é
-- dourado e sobe o número da sucata ganha.
function BoardRenderer.flashSpawn(self: Renderer, earlyBonus: number?)
	local spawn = self.spawnCell
	if not spawn then
		return
	end
	BoardRenderer.updateSpawnCountdown(self, nil, 0)
	local at = self.transform:logicalToScale(spawn[1], spawn[2])
	local color = if earlyBonus then Theme.colors.gold else Theme.colors.danger
	Juice.ring(self.layers.effects, at, 0.04, 0.22, color)
	Juice.burst(self.layers.effects, at, {
		count = if earlyBonus then 14 else 10,
		color = if earlyBonus then Theme.colors.gold else Theme.colors.coral,
		spread = 0.06,
	})
	if earlyBonus then
		Juice.floatText(self.layers.effects, at, "+" .. tostring(earlyBonus), Theme.colors.goldText)
	end
end

-- Melhoria de torre: a torre sobe de nível e isso precisa aparecer. Dois anéis dourados saindo
-- da célula, faíscas, o novo estado subindo em texto e um clarão curto por cima do sprite.
function BoardRenderer.playLevelUp(self: Renderer, x: number, y: number, state: string)
	local at = self.transform:logicalToScale(x, y)
	local gold = Theme.colors.gold
	Juice.ring(self.layers.effects, at, 0.02, 0.16, gold)
	task.delay(0.09, function()
		if self.layers.effects.Parent then
			Juice.ring(self.layers.effects, at, 0.02, 0.24, Theme.colors.glowWarm)
		end
	end)
	Juice.burst(self.layers.effects, at, { count = 16, color = gold, spread = 0.07, rise = 0.05 })
	Juice.floatText(self.layers.effects, at, state, Theme.colors.goldText, true)
	-- clarão: um disco claro que cresce e some em cima da célula
	local flash = Skin.frame(self.layers.effects, "LevelUpFlash", {
		Size = cellsToScale(1.2),
		Position = at,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.colors.white,
		BackgroundTransparency = 0.25,
		ZIndex = Z.effects + 8,
	})
	Skin.corner(flash, 9999)
	local grow = TweenService:Create(
		flash,
		TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = cellsToScale(2.6), BackgroundTransparency = 1 }
	)
	grow:Play()
	grow.Completed:Once(function()
		flash:Destroy()
	end)
	if not self.reducedMotion then
		Juice.shakeBoard(0.25)
	end
end

-- Onda limpa: comemoração curta no Farol.
function BoardRenderer.celebrateWaveEnd(self: Renderer)
	local base = self.baseCell
	if not base then
		return
	end
	local at = self.transform:logicalToScale(base[1], base[2])
	Juice.ring(self.layers.effects, at, 0.04, 0.26, Theme.colors.gold)
	Juice.burst(self.layers.effects, at, { count = 14, color = Theme.colors.gold, spread = 0.07, rise = 0.05 })
end

function BoardRenderer.playPulse(self: Renderer)
	local base = self.baseCell
	if not base then
		return
	end
	local ring = ringFrame(self, base[1], base[2], 0.5, Theme.colors.cyan, 4, Z.effects + 4)
	local duration = if self.reducedMotion then 0.3 else 0.7
	local t = TweenService:Create(
		ring,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = cellsToScale(40) }
	)
	t:Play()
	local stroke = ring:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(duration), { Transparency = 1 }):Play()
	end
	t.Completed:Once(function()
		ring:Destroy()
	end)
end

function BoardRenderer.setTelegraph(
	self: Renderer,
	entityId: number,
	cell: Types.Cell?,
	radius: number?,
	active: boolean
)
	local existing = self.telegraphRings[entityId]
	if existing then
		existing:Destroy()
		self.telegraphRings[entityId] = nil
	end
	if not active then
		return
	end
	local boss = self.enemies[entityId]
	if boss and not boss.dying then
		boss.animator:playTelegraph()
	end
	if cell and radius then
		local ring = ringFrame(self, cell[1], cell[2], radius, Theme.colors.danger, 3, Z.effects + 2)
		ring.BackgroundTransparency = 0.85
		ring.BackgroundColor3 = Theme.colors.danger
		Skin.label(ring, "Icon", "≋", {
			Size = UDim2.fromScale(0.3, 0.3),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.danger,
			ZIndex = Z.effects + 3,
		})
		self.telegraphRings[entityId] = ring
	end
end

-- Cura do Remendo: anel curto no curador e marca nos alvos efetivamente curados.
-- Os valores já foram aplicados no servidor; aqui só há apresentação.
function BoardRenderer.playHeal(self: Renderer, healerId: number, targets: { number }?, simNow: number)
	local healer = self.enemies[healerId]
	if healer and not healer.dying and not self.reducedParticles then
		local ring = ringFrame(self, healer.px, healer.py - 0.2, 0.75, Theme.colors.teal, 3, Z.effects + 2)
		local t = TweenService:Create(
			ring,
			TweenInfo.new(if self.reducedMotion then 0.15 else 0.35, Enum.EasingStyle.Quad),
			{ Size = cellsToScale(2.4), BackgroundTransparency = 1 }
		)
		local stroke = ring:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		t:Play()
		t.Completed:Once(function()
			ring:Destroy()
		end)
	end
	if targets then
		for _, id in ipairs(targets) do
			local visual = self.enemies[id]
			if visual and not visual.dying then
				visual.healMark.Visible = true
				visual.healUntil = simNow + 0.6
			end
		end
	end
end

function BoardRenderer.playAbility(
	self: Renderer,
	entityId: number,
	mechanic: string,
	cell: Types.Cell?,
	radius: number?,
	expiresAt: number?,
	entityIds: { number }?,
	simNow: number?
)
	BoardRenderer.setTelegraph(self, entityId, nil, nil, false)
	local boss = self.enemies[entityId]
	if boss and not boss.dying then
		boss.animator:playAbility()
	end
	if mechanic == "dust_pulse" and cell and radius then
		-- a nuvem permanece enquanto a poeira estiver ativa (prazo do servidor)
		local duration = 4
		if expiresAt and simNow then
			duration = math.max(0.3, expiresAt - simNow)
		end
		if self.reducedMotion then
			duration = math.min(duration, 0.6)
		end
		local ring = ringFrame(self, cell[1], cell[2], radius, Theme.colors.muted, 6, Z.effects + 2)
		ring.BackgroundColor3 = Theme.colors.muted
		ring.BackgroundTransparency = 0.7
		local t = TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			BackgroundTransparency = 1,
		})
		t:Play()
		t.Completed:Once(function()
			ring:Destroy()
		end)
	elseif mechanic == "summon" and entityIds then
		-- anel no ponto de invocação e entrada dos Corriscos
		local first = entityIds[1]
		local target = if first then self.enemies[first] else nil
		if target and not self.reducedParticles then
			local ring = ringFrame(self, target.px, target.py, 0.6, Theme.colors.enemy, 4, Z.effects + 2)
			local t = TweenService:Create(
				ring,
				TweenInfo.new(if self.reducedMotion then 0.15 else 0.35, Enum.EasingStyle.Quad),
				{ Size = cellsToScale(2), BackgroundTransparency = 1 }
			)
			local stroke = ring:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
			t:Play()
			t.Completed:Once(function()
				ring:Destroy()
			end)
		end
		for _, id in ipairs(entityIds) do
			BoardRenderer.playEnemySpawnIn(self, id)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Seleção, alcance e prévia de construção
-- ---------------------------------------------------------------------------

function BoardRenderer.setSelected(self: Renderer, towerId: number?)
	self.selectedTowerId = towerId
	if self.selection then
		self.selection:Destroy()
		self.selection = nil
	end
	if self.selectionRange then
		self.selectionRange:Destroy()
		self.selectionRange = nil
	end
	for _, line in pairs(self.circuitLines) do
		line.BackgroundColor3 = Theme.colors.cyan
		local stroke = line:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 1
		end
	end
	if not towerId then
		return
	end
	local visual = self.towers[towerId]
	if not visual then
		return
	end
	local data = visual.data
	local sel = Skin.frame(self.layers.selection, "Selection", {
		Size = cellsToScale(1.0),
		Position = self.transform:logicalToScale(data.x, data.y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = Z.selection,
	})
	Skin.corner(sel, 8)
	Skin.stroke(sel, Theme.colors.gold, 3)
	self.selection = sel
	local stats = Catalog.getStateStats(data.d, data.st)
	if stats then
		local range = ringFrame(self, data.x, data.y, stats.range, Theme.colors.cyan, 2, Z.selection)
		range.Parent = self.layers.selection
		range.BackgroundColor3 = Theme.colors.cyan
		range.BackgroundTransparency = 0.9
		self.selectionRange = range
	end
	if data.cp then
		local key = math.min(data.id, data.cp) .. "-" .. math.max(data.id, data.cp)
		local line = self.circuitLines[key]
		if line then
			line.BackgroundColor3 = Theme.colors.gold
			local stroke = line:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = 2
			end
		end
	end
end

export type BuildPreview = {
	towerId: string,
	x: number?,
	y: number?,
	valid: boolean,
	reason: string?,
	partnerId: number?,
	circuitId: string?,
	validCells: { Types.Cell }?,
}

function BoardRenderer.setBuildPreview(self: Renderer, preview: BuildPreview?)
	for _, f in ipairs(self.buildCells) do
		f:Destroy()
	end
	self.buildCells = {}
	if self.previewGhost then
		self.previewGhost:Destroy()
		self.previewGhost = nil
	end
	if self.previewRange then
		self.previewRange:Destroy()
		self.previewRange = nil
	end
	if self.previewLine then
		self.previewLine:Destroy()
		self.previewLine = nil
	end
	if not preview then
		return
	end
	if preview.validCells then
		-- Marca de célula livre: um contorno leve, não um véu. Com a arte nova, preencher todas
		-- as células deixava o mapa inteiro lavado (visto no Studio em 19/09).
		for _, cell in ipairs(preview.validCells) do
			local f = Skin.frame(self.layers.cells, "ValidCell", {
				Size = cellsToScale(0.9),
				Position = self.transform:logicalToScale(cell[1], cell[2]),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.colors.cream,
				BackgroundTransparency = 0.94,
				ZIndex = Z.cells,
			})
			Skin.corner(f, 8)
			local outline = Instance.new("UIStroke")
			outline.Color = Theme.colors.white
			outline.Thickness = 1
			outline.Transparency = 0.6
			outline.Parent = f
			table.insert(self.buildCells, f)
		end
	end
	local x, y = preview.x, preview.y
	if x == nil or y == nil then
		return
	end
	local ghost = Skin.frame(self.layers.effects, "Ghost", {
		Size = cellsToScale(TOWER_CELLS),
		Position = self.transform:logicalToScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.82),
		BackgroundTransparency = 1,
		ZIndex = Z.effects + 10,
	})
	local img, key = towerImageFor(preview.towerId, "L0")
	local image, fallback = makeImage(ghost, key, TOWER_CELLS, Z.effects + 10)
	image.ImageTransparency = 0.45
	if img == "" then
		fallback.Text = Theme.towerGlyphs[preview.towerId]
	end
	local cellMark = Skin.frame(ghost, "CellMark", {
		Size = UDim2.fromScale(1 / TOWER_CELLS, 1 / TOWER_CELLS),
		Position = UDim2.fromScale(0.5, 0.82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if preview.valid then Theme.colors.teal else Theme.colors.danger,
		BackgroundTransparency = 0.6,
		ZIndex = Z.effects + 9,
	})
	Skin.corner(cellMark, 6)
	Skin.stroke(cellMark, if preview.valid then Theme.colors.teal else Theme.colors.danger, 2)
	if not preview.valid then
		Skin.label(ghost, "Invalid", "✕ " .. Localization.get(preview.reason or "build.invalidCell"), {
			Size = UDim2.fromScale(2.4, 0.22),
			Position = UDim2.fromScale(0.5, 1.0),
			AnchorPoint = Vector2.new(0.5, 0),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.cream,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = Theme.colors.danger,
			Font = Theme.fonts.bodyBold,
			ZIndex = Z.effects + 11,
		})
	end
	self.previewGhost = ghost
	local stats = Catalog.getStateStats(preview.towerId, "L0")
	if stats then
		local range = ringFrame(
			self,
			x,
			y,
			stats.range,
			if preview.valid then Theme.colors.cyan else Theme.colors.danger,
			2,
			Z.effects + 8
		)
		range.BackgroundColor3 = Theme.colors.cyan
		range.BackgroundTransparency = 0.92
		self.previewRange = range
	end
	if preview.partnerId then
		local partner = self.towers[preview.partnerId]
		if partner then
			local horizontal = partner.data.y == y
			local line = Skin.frame(self.layers.effects, "PreviewCircuit", {
				Size = if horizontal
					then UDim2.fromScale(1 / Grid.COLUMNS, 0.09 / Grid.ROWS)
					else UDim2.fromScale(0.09 / Grid.COLUMNS, 1 / Grid.ROWS),
				Position = self.transform:logicalToScale((partner.data.x + x) / 2, (partner.data.y + y) / 2 + 0.05),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.colors.gold,
				ZIndex = Z.effects + 7,
			})
			Skin.corner(line, 999)
			Skin.stroke(line, Theme.colors.ink, 1)
			self.previewLine = line
		end
	end
end

function BoardRenderer.setShowRanges(self: Renderer, value: boolean)
	self.showRanges = value
	local existing = self.layers.selection:FindFirstChild("AllRanges")
	if existing then
		existing:Destroy()
	end
	if not value then
		return
	end
	local holder = Skin.frame(
		self.layers.selection,
		"AllRanges",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Z.selection }
	)
	for _, visual in pairs(self.towers) do
		local stats = Catalog.getStateStats(visual.data.d, visual.data.st)
		if stats then
			local ring = ringFrame(self, visual.data.x, visual.data.y, stats.range, Theme.colors.cyan, 1, Z.selection)
			ring.Parent = holder
		end
	end
end

function BoardRenderer.setShowCircuits(self: Renderer, value: boolean)
	self.showCircuits = value
	for _, line in pairs(self.circuitLines) do
		line.Visible = value
	end
end

function BoardRenderer.setCircuitPattern(self: Renderer, pattern: string)
	if self.circuitPattern ~= pattern then
		self.circuitPattern = pattern
		for key, line in pairs(self.circuitLines) do
			line:Destroy()
			self.circuitLines[key] = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- Frames e atualização por quadro
-- ---------------------------------------------------------------------------

function BoardRenderer.applyFrame(self: Renderer, view: MatchController.MatchView, events: { Types.NetEvent })
	local snapshot = view.snapshot
	if self.mapId ~= snapshot.mapId then
		BoardRenderer.setMap(self, snapshot.mapId)
	end
	if snapshot.full then
		BoardRenderer.syncTowers(self, view.towers, #snapshot.participants)
		if self.showRanges then
			BoardRenderer.setShowRanges(self, true)
		end
	end
	-- inimigos novos
	for id, ev in pairs(view.enemies) do
		if not self.enemies[id] then
			BoardRenderer.acquireEnemy(self, ev)
		end
	end
	local simNow = snapshot.simTime
	for _, e in ipairs(events) do
		if e.kind == "attack" and e.towerId and e.attackSeq and e.targets then
			BoardRenderer.playAttack(self, e.towerId, e.attackSeq, e.targets)
			for _, t in ipairs(e.targets) do
				BoardRenderer.showDamage(self, e.towerId, t.enemyId, t.damage, false)
				BoardRenderer.playEnemyHit(self, t.enemyId)
			end
		elseif e.kind == "support" and e.towerId and e.attackSeq then
			BoardRenderer.playAttack(self, e.towerId, e.attackSeq, {})
		elseif e.kind == "death" and e.entityId then
			BoardRenderer.playEnemyExit(self, e.entityId, "death")
		elseif e.kind == "leak" and e.entityId then
			BoardRenderer.playEnemyExit(self, e.entityId, "leak")
		elseif e.kind == "despawn" and e.entityId then
			BoardRenderer.releaseEnemy(self, e.entityId)
		elseif e.kind == "pulse" then
			BoardRenderer.playPulse(self)
			if e.targets then
				for _, t in ipairs(e.targets) do
					BoardRenderer.showDamage(self, 0, t.enemyId, t.damage, true)
					BoardRenderer.playEnemyHit(self, t.enemyId)
				end
			end
		elseif e.kind == "heal" and e.entityId then
			BoardRenderer.playHeal(self, e.entityId, e.entityIds, simNow)
		elseif e.kind == "bossTelegraph" and e.entityId then
			BoardRenderer.setTelegraph(self, e.entityId, e.cell, e.radius, true)
		elseif e.kind == "bossAbility" and e.entityId then
			BoardRenderer.playAbility(
				self,
				e.entityId,
				e.reason or "",
				e.cell,
				e.radius,
				e.expiresAt,
				e.entityIds,
				simNow
			)
		elseif e.kind == "bossCancel" and e.entityId then
			-- morte ou escape durante o aviso: nada é resolvido e o círculo sai da tela
			BoardRenderer.setTelegraph(self, e.entityId, nil, nil, false)
		end
	end
	-- inimigos que sumiram sem evento (reconciliação)
	for id, visual in pairs(self.enemies) do
		if not view.enemies[id] and not visual.dying then
			BoardRenderer.releaseEnemy(self, id)
		end
	end
	-- poeira nas torres
	for _, visual in pairs(self.towers) do
		visual.dust.Visible = visual.data.du > snapshot.simTime
	end
end

function BoardRenderer.update(self: Renderer, dt: number)
	local view = MatchController.current()
	if not view or not self.path then
		return
	end
	local path = self.path :: Path.PathData
	local renderTime = MatchController.renderTime()
	local simDt = dt * view.snapshot.speedMultiplier
	local cellPx = self.transform:cellPixels()
	for _, visual in pairs(self.towers) do
		visual.animator:update(simDt, self.reducedMotion, cellPx * TOWER_CELLS)
	end
	local simNow = MatchController.estimateSimTime()
	-- contagem da próxima onda: só nas fases de espera e quando existe prazo de verdade
	local snapshot = view.snapshot
	local waiting = snapshot.phase == "Preparation" or snapshot.phase == "Intermission"
	local deadline = snapshot.phaseEndsAt
	local left: number? = nil
	if waiting and deadline ~= math.huge then
		left = math.max(deadline - simNow, 0)
	end
	BoardRenderer.updateSpawnCountdown(self, left, dt)
	for id, visual in pairs(self.enemies) do
		local ev = view.enemies[id]
		if ev then
			local s = MatchController.enemyS(ev, renderTime)
			local px, py = Path.positionAt(path, s)
			visual.px, visual.py = px, py
			visual.container.Position = self.transform:logicalToScale(px, py)
			visual.shadow.Position = self.transform:logicalToScale(px, py + 0.02)
			local depth = Z.entities + math.floor(py * 100) + 1
			if depth ~= visual.depth then
				visual.depth = depth
				visual.container.ZIndex = depth
				visual.image.ZIndex = depth
				visual.hpBack.ZIndex = depth + 2
				visual.hpFill.ZIndex = depth + 3
				visual.status.ZIndex = depth + 3
				visual.resist.ZIndex = depth + 4
				visual.healMark.ZIndex = depth + 5
				visual.badge.ZIndex = depth + 5
				visual.name.ZIndex = depth + 3
			end
			-- movimento cosmético: um único controlador por entidade, no relógio da simulação
			visual.animator:update(simDt, self.reducedMotion)
			visual.hpFill.Size = UDim2.fromScale(math.clamp(ev.hp / math.max(ev.maxHp, 1), 0, 1), 1)
			local status = ""
			if ev.slow > 0 then
				status ..= "▼"
			end
			if ev.mark > 0 then
				status ..= "◎"
			end
			visual.status.Text = status
			visual.status.TextColor3 = if ev.mark > 0 and ev.slow <= 0 then Theme.colors.gold else Theme.colors.cyan
			if visual.healMark.Visible and simNow >= visual.healUntil then
				visual.healMark.Visible = false
			end
			-- Rei Ferrugem: escudo enquanto o reforço de armadura está ativo
			if ev.isBoss and ev.armorBonus > 0 then
				visual.resist.Text = "⛨"
				visual.resist.TextColor3 = Theme.colors.gold
				visual.resist.Visible = true
			elseif ev.isBoss then
				visual.resist.Visible = false
			end
			-- aviso de habilidade com contagem em segundos de simulação (prazo vem do servidor)
			local resolveAt = ev.telegraphAt
			if ev.telegraphing and resolveAt then
				local remaining = math.max(0, resolveAt - simNow)
				visual.badge.Text = string.format("%s %.1fs", bossBadgeIcon(ev.defId), remaining)
				visual.badge.Visible = true
			elseif visual.badge.Visible then
				visual.badge.Visible = false
			end
			visual.stroke.Enabled = ev.telegraphing
			if ev.telegraphing and not self.reducedMotion then
				visual.stroke.Transparency = 0.3 + 0.3 * math.sin(os.clock() * 6)
			end
		end
	end
	-- pulsação de Circuito recém-ativado
	for key, at in pairs(self.circuitPulse) do
		local line = self.circuitLines[key]
		local age = os.clock() - at
		if not line or age > 1.2 then
			self.circuitPulse[key] = nil
		elseif not self.reducedMotion then
			line.BackgroundColor3 = Theme.colors.cyan:Lerp(Theme.colors.gold, (math.sin(age * 10) + 1) / 2)
		end
	end
end

function BoardRenderer.towerVisual(self: Renderer, id: number): TowerVisual?
	return self.towers[id]
end

-- Inimigo mais próximo de um ponto lógico dentro do raio (para seleção/detalhe)
function BoardRenderer.nearestEnemy(self: Renderer, px: number, py: number, radius: number): number?
	local best: number? = nil
	local bestD = radius
	for id, visual in pairs(self.enemies) do
		local d = Grid.distance(px, py, visual.px, visual.py - 0.3)
		if d <= bestD then
			best = id
			bestD = d
		end
	end
	return best
end

function BoardRenderer.destroy(self: Renderer)
	for _, f in pairs(self.layers) do
		f:Destroy()
	end
end

return BoardRenderer
