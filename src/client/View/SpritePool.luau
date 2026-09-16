--!strict
-- Pool genérico de instâncias de interface para evitar criar e destruir objetos a cada onda.
local SpritePool = {}
SpritePool.__index = SpritePool

export type SpritePool<T> = typeof(setmetatable(
	{} :: {
		free: { T },
		factory: () -> T,
		reset: (T) -> (),
		created: number,
	},
	SpritePool
))

function SpritePool.new<T>(factory: () -> T, reset: (T) -> ()): SpritePool<T>
	return setmetatable({ free = {}, factory = factory, reset = reset, created = 0 }, SpritePool) :: any
end

function SpritePool.acquire<T>(self: SpritePool<T>): T
	local item = table.remove(self.free)
	if item == nil then
		item = self.factory()
		self.created += 1
	end
	return item :: T
end

function SpritePool.release<T>(self: SpritePool<T>, item: T)
	self.reset(item)
	table.insert(self.free, item)
end

function SpritePool.stats<T>(self: SpritePool<T>): (number, number)
	return self.created, #self.free
end

return SpritePool
