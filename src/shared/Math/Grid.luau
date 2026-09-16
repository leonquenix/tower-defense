--!strict
-- Geometria da grade lógica 16x10. Coordenadas lógicas são centros de células inteiras.
local Types = require(script.Parent.Parent.Types)

local Grid = {}

Grid.COLUMNS = 16
Grid.ROWS = 10
Grid.VIRTUAL_WIDTH = 960
Grid.VIRTUAL_HEIGHT = 600

function Grid.cellKey(x: number, y: number): number
	return x * 100 + y
end

function Grid.fromKey(key: number): (number, number)
	return math.floor(key / 100), key % 100
end

function Grid.isInteger(n: number): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and math.floor(n) == n
end

function Grid.inBounds(x: number, y: number): boolean
	return Grid.isInteger(x) and Grid.isInteger(y) and x >= 0 and x < Grid.COLUMNS and y >= 0 and y < Grid.ROWS
end

function Grid.isOrthogonallyAdjacent(ax: number, ay: number, bx: number, by: number): boolean
	local dx = math.abs(ax - bx)
	local dy = math.abs(ay - by)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
end

function Grid.distance(ax: number, ay: number, bx: number, by: number): number
	local dx = ax - bx
	local dy = ay - by
	return math.sqrt(dx * dx + dy * dy)
end

-- Conjunto de células (chaves) a partir de uma lista {x, y}
function Grid.cellSet(cells: { Types.Cell }): { [number]: boolean }
	local set: { [number]: boolean } = {}
	for _, c in ipairs(cells) do
		set[Grid.cellKey(c[1], c[2])] = true
	end
	return set
end

-- Transformação lógica -> virtual (sem zoom). O tabuleiro virtual mede 960x600.
function Grid.cellToVirtual(x: number, y: number, width: number?, height: number?): (number, number)
	local w = width or Grid.VIRTUAL_WIDTH
	local h = height or Grid.VIRTUAL_HEIGHT
	return (x + 0.5) * w / Grid.COLUMNS, (y + 0.5) * h / Grid.ROWS
end

-- Ponto contínuo (unidades de célula) -> virtual
function Grid.pointToVirtual(px: number, py: number, width: number?, height: number?): (number, number)
	local w = width or Grid.VIRTUAL_WIDTH
	local h = height or Grid.VIRTUAL_HEIGHT
	return (px + 0.5) * w / Grid.COLUMNS, (py + 0.5) * h / Grid.ROWS
end

-- Transformação inversa: retorna a célula ou nil se estiver fora do tabuleiro.
function Grid.virtualToCell(vx: number, vy: number, width: number?, height: number?): (number?, number?)
	local w = width or Grid.VIRTUAL_WIDTH
	local h = height or Grid.VIRTUAL_HEIGHT
	if vx ~= vx or vy ~= vy then
		return nil, nil
	end
	if vx < 0 or vy < 0 or vx >= w or vy >= h then
		return nil, nil
	end
	local x = math.floor(vx * Grid.COLUMNS / w)
	local y = math.floor(vy * Grid.ROWS / h)
	if x < 0 or x >= Grid.COLUMNS or y < 0 or y >= Grid.ROWS then
		return nil, nil
	end
	return x, y
end

return Grid
