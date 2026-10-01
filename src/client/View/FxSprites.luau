--!strict
-- Efeitos desenhados da encomenda v2 (projéteis, impactos, poeira de morte, gelo, coração...) em
-- ImageLabels reaproveitados e animados por quadro, sem Tween por efeito.
--
-- Cada efeito nasce de um evento que o servidor já confirmou; nada aqui decide jogo. `play` devolve
-- false quando a imagem ainda não foi publicada ou não carregou: aí o renderizador usa o visual
-- provisório antigo (bolinha, anel), que continua existindo justamente para esse caso.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Grid = require(ReplicatedStorage.Shared.Math.Grid)
local FramePreload = require(script.Parent.FramePreload)

local FxSprites = {}
FxSprites.__index = FxSprites

FxSprites.MAX_ACTIVE = 160

export type Spec = {
	name: string, -- efeito (fx_<name> em Assets)
	at: UDim2, -- posição inicial (escala do mundo)
	size: number, -- largura em células
	duration: number, -- segundos reais
	to: UDim2?, -- voo até aqui (projétil)
	grow: number?, -- largura final em células
	rotation: number?, -- graus (projétil aponta para a direita)
	fadeFrom: number?, -- fração da duração em que começa a sumir (padrão 0,6)
	sequence: { string }?, -- quadros trocados ao longo da duração (poeira 1 -> 2 -> 3)
	transparency: number?, -- transparência inicial
	zOffset: number?,
}

type Active = {
	label: ImageLabel,
	spec: Spec,
	age: number,
	images: { string }?,
	frameIndex: number,
}

export type FxSprites = typeof(setmetatable(
	{} :: {
		layer: Frame,
		z: number,
		free: { ImageLabel },
		active: { Active },
	},
	FxSprites
))

local function cells(c: number): UDim2
	return UDim2.fromScale(c / Grid.COLUMNS, c / Grid.ROWS)
end

-- Imagem do efeito pronta para uso (publicada e carregada).
function FxSprites.image(name: string): string?
	local entry = Assets.get(Assets.fxKey(name))
	local image = if entry then entry.image else nil
	if image and FramePreload.ready(image) then
		return image
	end
	return nil
end

-- Pede o carregamento de todos os efeitos publicados (uma vez por partida basta).
function FxSprites.preloadAll()
	local ids: { string } = {}
	for _, entry in pairs(Assets.entries) do
		if entry.kind == "fx" and entry.image then
			table.insert(ids, entry.image :: string)
		end
	end
	FramePreload.request(ids)
end

function FxSprites.new(layer: Frame, z: number): FxSprites
	return setmetatable({ layer = layer, z = z, free = {}, active = {} }, FxSprites)
end

local function acquire(self: FxSprites): ImageLabel
	local label = table.remove(self.free)
	if label then
		return label
	end
	local created = Instance.new("ImageLabel")
	created.Name = "Fx"
	created.BackgroundTransparency = 1
	created.ScaleType = Enum.ScaleType.Fit
	created.AnchorPoint = Vector2.new(0.5, 0.5)
	created.Active = false
	created.Parent = self.layer
	return created
end

function FxSprites.play(self: FxSprites, spec: Spec): boolean
	local images: { string }? = nil
	local first: string?
	if spec.sequence then
		local list: { string } = {}
		for _, name in ipairs(spec.sequence) do
			local image = FxSprites.image(name)
			if not image then
				return false
			end
			table.insert(list, image)
		end
		images = list
		first = list[1]
	else
		first = FxSprites.image(spec.name)
	end
	if not first then
		return false
	end
	if #self.active >= FxSprites.MAX_ACTIVE then
		return true -- tabuleiro lotado: o efeito é só enfeite, então some sem substituto
	end
	local label = acquire(self)
	label.Image = first :: string
	label.Position = spec.at
	label.Size = cells(spec.size)
	label.Rotation = spec.rotation or 0
	label.ImageTransparency = spec.transparency or 0
	label.ZIndex = self.z + (spec.zOffset or 0)
	label.Visible = true
	table.insert(self.active, { label = label, spec = spec, age = 0, images = images, frameIndex = 1 })
	return true
end

local function release(self: FxSprites, item: Active)
	item.label.Visible = false
	table.insert(self.free, item.label)
end

function FxSprites.update(self: FxSprites, dt: number)
	local i = 1
	local active = self.active
	while i <= #active do
		local item = active[i]
		local spec = item.spec
		item.age += dt
		local p = item.age / math.max(spec.duration, 1e-3)
		if p >= 1 then
			release(self, item)
			table.remove(active, i)
		else
			local label = item.label
			if spec.to then
				label.Position = spec.at:Lerp(spec.to, p)
			end
			if spec.grow then
				label.Size = cells(spec.size + (spec.grow - spec.size) * p)
			end
			local images = item.images
			if images then
				local index = math.min(#images, math.floor(p * #images) + 1)
				if index ~= item.frameIndex then
					item.frameIndex = index
					label.Image = images[index]
				end
			end
			local fadeFrom = spec.fadeFrom or 0.6
			local base = spec.transparency or 0
			if p > fadeFrom then
				label.ImageTransparency = base + (1 - base) * (p - fadeFrom) / (1 - fadeFrom)
			end
			i += 1
		end
	end
end

-- Fim de partida ou troca de mapa: nenhum efeito sobra na tela.
function FxSprites.clear(self: FxSprites)
	for _, item in ipairs(self.active) do
		release(self, item)
	end
	self.active = {}
end

function FxSprites.activeCount(self: FxSprites): number
	return #self.active
end

return FxSprites
