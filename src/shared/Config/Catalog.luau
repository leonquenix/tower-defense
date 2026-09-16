--!strict
-- Índices de acesso rápido sobre os dados gerados (Balance e Maps).
local Types = require(script.Parent.Parent.Types)
local Balance = require(script.Parent.Balance)
local Maps = require(script.Parent.Maps)

local Catalog = {}

local STATE_ORDER: { Types.TowerStateId } = { "L0", "L1", "L2", "L3A", "L3B" }
local TRANSITIONS: { [string]: { Types.TowerStateId } } = {
	L0 = { "L1" },
	L1 = { "L2" },
	L2 = { "L3A", "L3B" },
	L3A = {},
	L3B = {},
}
local TARGET_MODES: { Types.TargetMode } = { "first", "last", "strongest", "closest" }
Catalog.STATE_ORDER = STATE_ORDER
Catalog.TRANSITIONS = TRANSITIONS
Catalog.TARGET_MODES = TARGET_MODES

local towersById: { [string]: Types.TowerDef } = {}
for _, t in ipairs(Balance.towers) do
	towersById[t.id] = t
end
local enemiesById: { [string]: Types.EnemyDef } = {}
for _, e in ipairs(Balance.enemies) do
	enemiesById[e.id] = e
end
local bossesById: { [string]: Types.BossDef } = {}
for _, b in ipairs(Balance.bosses) do
	bossesById[b.id] = b
end
local mapsById: { [string]: Maps.MapEntry } = {}
for _, m in ipairs(Maps) do
	mapsById[m.id] = m
end
local circuitsByPair: { [string]: Types.CircuitDef } = {}
for _, c in ipairs(Balance.circuits) do
	circuitsByPair[c.pair[1] .. "|" .. c.pair[2]] = c
	circuitsByPair[c.pair[2] .. "|" .. c.pair[1]] = c
end

Catalog.towersById = towersById
Catalog.enemiesById = enemiesById
Catalog.bossesById = bossesById
Catalog.mapsById = mapsById
Catalog.circuitsByPair = circuitsByPair

function Catalog.getTower(id: string): Types.TowerDef?
	return towersById[id]
end

function Catalog.getEnemy(id: string): Types.EnemyDef?
	return enemiesById[id]
end

function Catalog.getBoss(id: string): Types.BossDef?
	return bossesById[id]
end

function Catalog.getMap(id: string): Maps.MapEntry?
	return mapsById[id]
end

function Catalog.getCircuitFor(towerA: string, towerB: string): Types.CircuitDef?
	return circuitsByPair[towerA .. "|" .. towerB]
end

function Catalog.isValidState(state: string): boolean
	return Catalog.TRANSITIONS[state] ~= nil
end

function Catalog.canTransition(from: string, to: string): boolean
	local nexts = Catalog.TRANSITIONS[from]
	if not nexts then
		return false
	end
	return table.find(nexts, to :: any) ~= nil
end

function Catalog.getStateStats(towerId: string, state: string): Types.TowerStateStats?
	local def = towersById[towerId]
	if not def then
		return nil
	end
	return def.states[state]
end

function Catalog.getWave(index: number): Types.WaveDef?
	return Balance.waves[index]
end

function Catalog.getDifficulty(id: string): Types.DifficultyDef?
	return Balance.difficulties[id]
end

function Catalog.getBranchName(towerId: string, state: string): string?
	local def = towersById[towerId]
	if not def then
		return nil
	end
	if state == "L3A" then
		return def.branchNames[1]
	elseif state == "L3B" then
		return def.branchNames[2]
	end
	return nil
end

function Catalog.starterTowerIds(): { string }
	local list = {}
	for _, t in ipairs(Balance.towers) do
		if t.starter then
			table.insert(list, t.id)
		end
	end
	return list
end

function Catalog.towerLimitForPartySize(size: number): number
	local limits = Balance.playerTowerLimitsByPartySize
	local idx = math.clamp(size, 1, #limits)
	return limits[idx]
end

return Catalog
