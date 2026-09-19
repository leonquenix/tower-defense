local Grid = load("Shared/Math/Grid")
local Path = load("Shared/Math/Path")
local Maps = load("Shared/Config/Maps")
local Balance = load("Shared/Config/Balance")

describe("Grid", function()
	it("valida limites e inteiros", function()
		expect(Grid.inBounds(0, 0)).toBe(true)
		expect(Grid.inBounds(15, 9)).toBe(true)
		expect(Grid.inBounds(16, 0)).toBe(false)
		expect(Grid.inBounds(3.5, 2)).toBe(false)
		expect(Grid.inBounds(0 / 0, 2)).toBe(false)
		expect(Grid.inBounds(math.huge, 2)).toBe(false)
	end)
	it("converte célula para virtual e de volta", function()
		local vx, vy = Grid.cellToVirtual(3, 3)
		expect(vx).toBeCloseTo(210)
		expect(vy).toBeCloseTo(210)
		local cx, cy = Grid.virtualToCell(vx, vy)
		expect(cx).toBe(3)
		expect(cy).toBe(3)
		local nx = Grid.virtualToCell(-1, 10)
		expect(nx).toBeNil()
		local ex = Grid.virtualToCell(960, 10)
		expect(ex).toBeNil()
		local lx, ly = Grid.virtualToCell(959.9, 599.9)
		expect(lx).toBe(15)
		expect(ly).toBe(9)
	end)
	it("reconhece adjacência ortogonal apenas", function()
		expect(Grid.isOrthogonallyAdjacent(3, 3, 3, 4)).toBe(true)
		expect(Grid.isOrthogonallyAdjacent(3, 3, 4, 4)).toBe(false)
		expect(Grid.isOrthogonallyAdjacent(3, 3, 3, 3)).toBe(false)
	end)
end)

describe("Path", function()
	local jardim = nil
	for _, m in ipairs(Maps) do
		if m.id == "jardim" then
			jardim = m
		end
	end
	local path = Path.build(jardim.path)
	-- A arte do mapa manda na rota, e ela muda quando o cenário é redesenhado. Por isso o teste
	-- cobre as invariantes (soma dos trechos, células = comprimento + 1, extremos) em vez de
	-- números escritos à mão, que envelheciam a cada arte nova.
	local first = jardim.path[1]
	local last = jardim.path[#jardim.path]
	local expectedLength = 0
	for i = 1, #jardim.path - 1 do
		local a, b = jardim.path[i], jardim.path[i + 1]
		expectedLength += math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])
	end
	it("calcula comprimento total do Jardim", function()
		expect(path.totalLength).toBe(expectedLength)
		-- caminho ortogonal sem repetir célula: uma célula por passo, mais a de partida
		expect(#jardim.pathCells).toBe(expectedLength + 1)
	end)
	it("interpola posições ao longo do caminho", function()
		local x, y = Path.positionAt(path, 0)
		expect(x).toBe(first[1])
		expect(y).toBe(first[2])
		-- fim do primeiro trecho
		local legOne = math.abs(jardim.path[2][1] - first[1]) + math.abs(jardim.path[2][2] - first[2])
		x, y = Path.positionAt(path, legOne)
		expect(x).toBeCloseTo(jardim.path[2][1])
		expect(y).toBeCloseTo(jardim.path[2][2])
		-- meio do segundo trecho
		local legTwo = math.abs(jardim.path[3][1] - jardim.path[2][1]) + math.abs(jardim.path[3][2] - jardim.path[2][2])
		x, y = Path.positionAt(path, legOne + legTwo / 2)
		expect(x).toBeCloseTo((jardim.path[2][1] + jardim.path[3][1]) / 2)
		expect(y).toBeCloseTo((jardim.path[2][2] + jardim.path[3][2]) / 2)
		-- passar do fim para na última célula
		x, y = Path.positionAt(path, expectedLength + 50)
		expect(x).toBe(last[1])
		expect(y).toBe(last[2])
	end)
	it("marca células do caminho", function()
		for _, cell in ipairs(jardim.pathCells) do
			expect(Path.isPathCell(path, cell[1], cell[2])).toBe(true)
		end
		-- célula do guia da primeira fase: tem de ser grama, senão o guia manda construir no caminho
		local intro = Balance.campaign.levels[1].introCell
		expect(Path.isPathCell(path, intro[1], intro[2])).toBe(false)
	end)
	it("rejeita caminhos diagonais", function()
		expect(function()
			Path.build({ { 0, 0 }, { 1, 1 } })
		end).toThrow()
	end)
end)
