--!strict
-- Tabelas de enumeração compartilhadas pela rede binária (ByteNet).
--
-- Em vez de mandar "fiapo", "L3A" ou "Preparation" a cada quadro, o fio carrega um inteiro.
-- As listas vêm dos dados gerados (Balance/Maps), então cliente e servidor derivam exatamente a
-- mesma ordem a partir da mesma fonte: não existe tabela de ids escrita à mão para dessincronizar.
--
-- Id 0 é reservado para "ausente/desconhecido"; os valores começam em 1. Quem lê sempre aceita
-- um id desconhecido e devolve nil, para que uma versão nova do servidor não derrube o cliente.
local Balance = require(script.Parent.Parent.Config.Balance)
local Maps = require(script.Parent.Parent.Config.Maps)

local Enums = {}

export type EnumSet = {
	name: string,
	values: { string },
	index: { [string]: number },
}

local function set(name: string, values: { string }): EnumSet
	local index: { [string]: number } = {}
	for i, value in ipairs(values) do
		assert(index[value] == nil, `valor repetido em {name}: {value}`)
		index[value] = i
	end
	return { name = name, values = values, index = index }
end

local function ids(list: { { id: string } }): { string }
	local out: { string } = {}
	for _, entry in ipairs(list) do
		table.insert(out, entry.id)
	end
	return out
end

-- Inimigos e chefes num único espaço de ids (o snapshot marca quem é chefe com um booleano).
local enemyValues = ids(Balance.enemies :: any)
for _, id in ipairs(ids(Balance.bosses :: any)) do
	table.insert(enemyValues, id)
end

Enums.enemy = set("enemy", enemyValues)
Enums.tower = set("tower", ids(Balance.towers :: any))
Enums.towerState = set("towerState", { "L0", "L1", "L2", "L3A", "L3B" })
Enums.targetMode = set("targetMode", { "first", "last", "strongest", "closest" })
Enums.difficulty = set("difficulty", { "normal", "desafio" })
Enums.matchMode = set("matchMode", { "normal", "training" })
Enums.map = set("map", ids(Maps :: any))
Enums.circuit = set("circuit", ids(Balance.circuits :: any))
Enums.phase = set("phase", {
	"Lobby",
	"Loading",
	"Preparation",
	"Wave",
	"Intermission",
	"Won",
	"Lost",
	"RewardPending",
	"Closed",
	"Abandoned",
})

-- Eventos cosméticos do combate (Simulation) — a lista é um atalho de tamanho, não um contrato:
-- Codec manda o nome por extenso quando o id não é conhecido dos dois lados.
Enums.event = set("event", {
	"attack",
	"support",
	"death",
	"despawn",
	"spawn",
	"spawnDeferred",
	"leak",
	"heal",
	"pulse",
	"phase",
	"presence",
	"waveStart",
	"waveEnd",
	"waveIncome",
	"earlyBonus",
	"matchEnd",
	"towerPlaced",
	"towerSold",
	"towerUpgraded",
	"circuitChanged",
	"speedChanged",
	"bossSpawn",
	"bossTelegraph",
	"bossAbility",
	"bossCancel",
})

-- Quadros da partida (servidor -> cliente) e avisos de lobby.
Enums.frame = set("frame", { "frame", "match", "result", "left", "rematch" })
Enums.lobby = set("lobby", { "lobby", "invite", "profile", "shop", "reward" })

-- Converte texto -> id (0 quando nil ou fora da lista).
function Enums.toId(enumSet: EnumSet, value: string?): number
	if value == nil then
		return 0
	end
	return enumSet.index[value :: string] or 0
end

-- Converte id -> texto (nil quando 0 ou fora da lista).
function Enums.toValue(enumSet: EnumSet, id: number): string?
	if id <= 0 then
		return nil
	end
	return enumSet.values[id]
end

-- Como acima, mas garante um valor: usado onde o campo não pode faltar.
function Enums.toValueOr(enumSet: EnumSet, id: number, fallback: string): string
	return Enums.toValue(enumSet, id) or fallback
end

function Enums.count(enumSet: EnumSet): number
	return #enumSet.values
end

return Enums
