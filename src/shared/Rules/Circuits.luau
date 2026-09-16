--!strict
-- Circuitos por adjacência ortogonal. Pareamento determinístico por ID.
local Types = require(script.Parent.Parent.Types)
local Grid = require(script.Parent.Parent.Math.Grid)

local Circuits = {}

export type Assignment = { partnerId: number, circuitId: string }
export type Candidate = { lowId: number, highId: number, circuitId: string }

-- towers: lista de torres (qualquer ordem). lookupCircuit(defA, defB) -> CircuitDef?
function Circuits.candidates(
	towers: { Types.Tower },
	lookupCircuit: (string, string) -> Types.CircuitDef?
): { Candidate }
	local list: { Candidate } = {}
	for i = 1, #towers do
		local a = towers[i]
		for j = i + 1, #towers do
			local b = towers[j]
			if Grid.isOrthogonallyAdjacent(a.x, a.y, b.x, b.y) then
				local def = lookupCircuit(a.defId, b.defId)
				if def then
					local low = math.min(a.id, b.id)
					local high = math.max(a.id, b.id)
					table.insert(list, { lowId = low, highId = high, circuitId = def.id })
				end
			end
		end
	end
	table.sort(list, function(p, q)
		if p.lowId ~= q.lowId then
			return p.lowId < q.lowId
		end
		return p.highId < q.highId
	end)
	return list
end

-- Retorna atribuições {[towerId] = Assignment}. Cada torre participa de no máximo um Circuito.
function Circuits.assign(
	towers: { Types.Tower },
	lookupCircuit: (string, string) -> Types.CircuitDef?
): { [number]: Assignment }
	local result: { [number]: Assignment } = {}
	for _, c in ipairs(Circuits.candidates(towers, lookupCircuit)) do
		if result[c.lowId] == nil and result[c.highId] == nil then
			result[c.lowId] = { partnerId = c.highId, circuitId = c.circuitId }
			result[c.highId] = { partnerId = c.lowId, circuitId = c.circuitId }
		end
	end
	return result
end

-- Prévia: qual par seria ativado se uma torre hipotética fosse colocada em (x, y).
function Circuits.preview(
	towers: { Types.Tower },
	hypothetical: Types.Tower,
	lookupCircuit: (string, string) -> Types.CircuitDef?
): Assignment?
	local list = table.clone(towers)
	table.insert(list, hypothetical)
	local assignments = Circuits.assign(list, lookupCircuit)
	return assignments[hypothetical.id]
end

return Circuits
