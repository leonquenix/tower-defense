--!strict
-- Caminho fixo: segmentos ortogonais pré-calculados; posição por distância escalar s.
local Types = require(script.Parent.Parent.Types)

export type Segment = {
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	length: number,
	startS: number,
}

export type PathData = {
	points: { Types.Cell },
	segments: { Segment },
	totalLength: number,
	cellSet: { [number]: boolean },
}

local Path = {}

function Path.build(points: { Types.Cell }): PathData
	assert(#points >= 2, "caminho precisa de ao menos dois pontos")
	local segments: { Segment } = {}
	local total = 0
	local cellSet: { [number]: boolean } = {}
	for i = 1, #points - 1 do
		local a = points[i]
		local b = points[i + 1]
		assert(a[1] == b[1] or a[2] == b[2], "segmento de caminho não ortogonal")
		local length = math.abs(b[1] - a[1]) + math.abs(b[2] - a[2])
		assert(length > 0, "segmento de comprimento zero")
		table.insert(segments, { x0 = a[1], y0 = a[2], x1 = b[1], y1 = b[2], length = length, startS = total })
		total += length
		local dx = math.sign(b[1] - a[1])
		local dy = math.sign(b[2] - a[2])
		local x, y = a[1], a[2]
		for _ = 0, length do
			cellSet[x * 100 + y] = true
			x += dx
			y += dy
		end
	end
	return { points = points, segments = segments, totalLength = total, cellSet = cellSet }
end

-- Posição contínua (em unidades de célula) para uma distância s ao longo do caminho.
function Path.positionAt(path: PathData, s: number): (number, number)
	if s <= 0 then
		local p = path.points[1]
		return p[1], p[2]
	end
	if s >= path.totalLength then
		local p = path.points[#path.points]
		return p[1], p[2]
	end
	local segments = path.segments
	-- busca binária pelo segmento
	local lo, hi = 1, #segments
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if segments[mid].startS <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local seg = segments[lo]
	local t = (s - seg.startS) / seg.length
	return seg.x0 + (seg.x1 - seg.x0) * t, seg.y0 + (seg.y1 - seg.y0) * t
end

function Path.isPathCell(path: PathData, x: number, y: number): boolean
	return path.cellSet[x * 100 + y] == true
end

-- Direção unitária do segmento que contém s (para orientar setas/curvas na apresentação).
function Path.directionAt(path: PathData, s: number): (number, number)
	local segments = path.segments
	local seg = segments[#segments]
	for i = 1, #segments do
		if segments[i].startS <= s then
			seg = segments[i]
		else
			break
		end
	end
	return math.sign(seg.x1 - seg.x0), math.sign(seg.y1 - seg.y0)
end

return Path
