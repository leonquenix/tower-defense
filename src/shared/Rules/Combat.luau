--!strict
-- Regras puras de combate: dano, resistências, efeitos, aquisição de alvos, explosão e corrente.
local Types = require(script.Parent.Parent.Types)
local Grid = require(script.Parent.Parent.Math.Grid)

local Combat = {}

export type DamageInput = {
	baseDamage: number,
	damageType: Types.DamageType,
	bossBonus: number?, -- bônus contra chefe da torre (só vale se isBoss)
	circuitBonus: number?, -- bônus de Circuito aplicável a este acerto
	armorIgnore: number?,
	mark: number, -- maior marca ativa no alvo
	armor: number, -- armadura atual do alvo (inclui bônus de chefe)
	energyResistance: number,
	isBoss: boolean,
	armorCap: number,
}

function Combat.effectiveArmor(armor: number, armorIgnore: number?, armorCap: number): number
	local ignore = armorIgnore or 0
	return math.clamp(armor * (1 - ignore), 0, armorCap)
end

function Combat.computeDamage(input: DamageInput): number
	local bossBonus = if input.isBoss then (input.bossBonus or 0) else 0
	local bonus = (1 + bossBonus) * (1 + (input.circuitBonus or 0))
	local vulnerability = 1 + input.mark
	local resistance = 0
	if input.damageType == "physical" then
		resistance = Combat.effectiveArmor(input.armor, input.armorIgnore, input.armorCap)
	elseif input.damageType == "energy" then
		resistance = math.clamp(input.energyResistance, 0, 1)
	end
	return input.baseDamage * bonus * vulnerability * (1 - resistance)
end

-- Remove efeitos expirados (in place) e devolve a maior força ativa.
function Combat.pruneAndMax(effects: { Types.TimedEffect }, simTime: number): number
	local maxStrength = 0
	local i = 1
	while i <= #effects do
		local e = effects[i]
		if e.expiresAt <= simTime then
			table.remove(effects, i)
		else
			if e.strength > maxStrength then
				maxStrength = e.strength
			end
			i += 1
		end
	end
	return maxStrength
end

-- Lentidão ativa efetiva: maior força; chefes multiplicam por bossSlowStrength antes do limite.
function Combat.activeSlow(enemy: Types.Enemy, simTime: number, effects: Types.EffectsDef): number
	local strength = Combat.pruneAndMax(enemy.slows, simTime)
	if strength <= 0 then
		return 0
	end
	if enemy.isBoss then
		strength *= effects.bossSlowStrength
	end
	return math.min(strength, effects.slowCap)
end

function Combat.activeMark(enemy: Types.Enemy, simTime: number): number
	return Combat.pruneAndMax(enemy.marks, simTime)
end

function Combat.isSlowed(enemy: Types.Enemy, simTime: number): boolean
	return Combat.pruneAndMax(enemy.slows, simTime) > 0
end

-- Aplica/renova um efeito temporizado. Marcas e lentidões não se somam: guardamos todas
-- e usamos a maior ativa; a mesma fonte renova sua duração em vez de duplicar.
function Combat.applyEffect(
	effects: { Types.TimedEffect },
	strength: number,
	duration: number,
	sourceTowerId: number,
	simTime: number
)
	local expiresAt = simTime + duration
	for _, e in ipairs(effects) do
		if e.sourceTowerId == sourceTowerId and e.strength == strength then
			e.expiresAt = math.max(e.expiresAt, expiresAt)
			return
		end
	end
	table.insert(effects, { strength = strength, expiresAt = expiresAt, sourceTowerId = sourceTowerId })
end

function Combat.currentArmor(enemy: Types.Enemy, simTime: number): number
	if enemy.isBoss and enemy.bossArmorUntil > simTime then
		return enemy.armor + enemy.bossArmorBonus
	end
	return enemy.armor
end

-- Intervalo efetivo com aura (maior haste) e poeira do Aspirador.
function Combat.effectiveInterval(baseInterval: number, haste: number, dusted: boolean, dustFactor: number): number
	local interval = baseInterval / (1 + haste)
	if dusted then
		interval /= dustFactor
	end
	return interval
end

export type TowerPos = { x: number, y: number }

-- Maior haste de Maestros em alcance da torre (Maestro não acelera Maestro).
function Combat.hasteFor(
	tower: Types.Tower,
	towers: { Types.Tower },
	getHaste: (Types.Tower) -> number?,
	getRange: (Types.Tower) -> number
): number
	if tower.defId == "maestro" then
		return 0
	end
	local best = 0
	for _, other in ipairs(towers) do
		if other.id ~= tower.id then
			local haste = getHaste(other)
			if haste and haste > 0 then
				local d = Grid.distance(tower.x, tower.y, other.x, other.y)
				if d <= getRange(other) + 1e-9 and haste > best then
					best = haste
				end
			end
		end
	end
	return best
end

export type EnemyPos = { enemy: Types.Enemy, px: number, py: number }

-- Seleção de alvo entre inimigos vivos em alcance. Empates: menor ID.
function Combat.selectTarget(
	tower: Types.Tower,
	range: number,
	candidates: { EnemyPos },
	mode: Types.TargetMode
): EnemyPos?
	local best: EnemyPos? = nil
	local bestScore = 0
	for _, c in ipairs(candidates) do
		local e = c.enemy
		if e.alive then
			local d = Grid.distance(tower.x, tower.y, c.px, c.py)
			if d <= range + 1e-9 then
				local score: number
				if mode == "first" then
					score = e.s
				elseif mode == "last" then
					score = -e.s
				elseif mode == "strongest" then
					score = e.hp
				else
					score = -d
				end
				if
					best == nil
					or score > bestScore + 1e-9
					or (math.abs(score - bestScore) <= 1e-9 and e.id < best.enemy.id)
				then
					best = c
					bestScore = score
				end
			end
		end
	end
	return best
end

-- Alvos de explosão: primário + mais próximos do centro do primário (raio inclusive), até maxTargets no total.
function Combat.splashTargets(
	primary: EnemyPos,
	candidates: { EnemyPos },
	radius: number,
	maxTargets: number
): { EnemyPos }
	local others: { { pos: EnemyPos, d: number } } = {}
	for _, c in ipairs(candidates) do
		if c.enemy.alive and c.enemy.id ~= primary.enemy.id then
			local d = Grid.distance(primary.px, primary.py, c.px, c.py)
			if d <= radius + 1e-9 then
				table.insert(others, { pos = c, d = d })
			end
		end
	end
	table.sort(others, function(a, b)
		if math.abs(a.d - b.d) > 1e-9 then
			return a.d < b.d
		end
		return a.pos.enemy.id < b.pos.enemy.id
	end)
	local result = { primary }
	for _, o in ipairs(others) do
		if #result >= maxTargets then
			break
		end
		table.insert(result, o.pos)
	end
	return result
end

-- Alvos de corrente: cada salto procura o inimigo ainda não atingido mais próximo do anterior dentro de chainRadius.
function Combat.chainTargets(
	primary: EnemyPos,
	candidates: { EnemyPos },
	chains: number,
	chainRadius: number
): { EnemyPos }
	local result = { primary }
	local hit: { [number]: boolean } = { [primary.enemy.id] = true }
	local last = primary
	while #result < chains do
		local best: EnemyPos? = nil
		local bestD = math.huge
		for _, c in ipairs(candidates) do
			local e = c.enemy
			if e.alive and not hit[e.id] then
				local d = Grid.distance(last.px, last.py, c.px, c.py)
				if d <= chainRadius + 1e-9 then
					if d < bestD - 1e-9 or (math.abs(d - bestD) <= 1e-9 and best ~= nil and e.id < best.enemy.id) then
						best = c
						bestD = d
					end
				end
			end
		end
		if best == nil then
			break
		end
		hit[best.enemy.id] = true
		table.insert(result, best)
		last = best
	end
	return result
end

-- Fração restante de cooldown preservada ao melhorar (evita disparo grátis ao comprar).
function Combat.carryCooldown(cooldown: number, oldInterval: number, newInterval: number): number
	if oldInterval <= 0 or cooldown <= 0 then
		return 0
	end
	return (cooldown / oldInterval) * newInterval
end

return Combat
