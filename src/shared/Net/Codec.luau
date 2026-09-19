--!strict
-- Conversão entre as estruturas do jogo (Types) e as estruturas do fio (ByteNet).
--
-- Tudo aqui é puro: nenhuma dependência de Roblox, nenhum acesso a serviço. É de propósito —
-- assim o ida-e-volta é testável fora do Studio (tests/specs/04_protocol.spec.luau) e o módulo
-- de pacotes fica só com a definição binária.
--
-- Regras:
--  * identificadores viram ids de Enums (uint8) em vez de texto repetido a cada quadro;
--  * campos ausentes viajam como `nil` (optional do ByteNet: 1 byte), não como zero;
--  * decodificar um id desconhecido devolve nil em vez de erro — servidor novo, cliente antigo.
local Types = require(script.Parent.Parent.Types)
local Catalog = require(script.Parent.Parent.Config.Catalog)
local Enums = require(script.Parent.Enums)

-- A fase viaja como índice (1 byte) em vez de texto a cada quadro.
local function levelIdByIndex(index: number): string?
	local level = Catalog.levels()[index]
	return if level then level.id else nil
end

local Codec = {}

-- ---------------------------------------------------------------------------
-- Tipos do fio
-- ---------------------------------------------------------------------------

export type WireEnemy = {
	id: number,
	d: number,
	b: boolean,
	hp: number,
	mhp: number,
	s: number,
	v: number,
	sl: number,
	mk: number,
	sm: boolean,
	tg: boolean,
	tga: number?,
	ab: number,
	ar: number,
	er: number,
}

export type WireTower = {
	id: number,
	o: number,
	d: number,
	st: number,
	x: number,
	y: number,
	tm: number,
	inv: number,
	cp: number?,
	ci: number,
	du: number,
}

export type WireParticipant = {
	u: number,
	n: string,
	c: boolean,
	r: boolean,
	sv: number,
	col: number,
}

export type WireGroup = { e: number, n: number }

export type WireSnapshot = {
	matchId: string,
	mode: number,
	map: number,
	diff: number,
	phase: number,
	wave: number,
	total: number,
	hp: number,
	t: number,
	speed: number,
	ends: number,
	pulse: number,
	rev: number,
	wallet: number,
	limit: number,
	placed: number,
	full: boolean,
	unlockAll: boolean,
	level: number, -- índice da fase na campanha (0 = fora da campanha)
	dmg: number,
	built: number,
	rushed: number,
	enemies: { WireEnemy },
	towers: { WireTower },
	parts: { WireParticipant },
	preview: { WireGroup },
}

export type WireTarget = { e: number, d: number, i: number }

export type WireEvent = {
	k: number,
	ks: string?, -- nome por extenso quando o id não é conhecido
	t: number,
	entity: number?,
	tower: number?,
	seq: number?,
	user: number?,
	amount: number?,
	wave: number?,
	phase: number?,
	enemyDef: number?,
	circuit: number?,
	partner: number?,
	radius: number?,
	s: number?,
	resolveAt: number?,
	expiresAt: number?,
	cellX: number?,
	cellY: number?,
	reason: string?,
	code: string?,
	speed: number?,
	targets: { WireTarget },
	entityIds: { number },
	towerIds: { number },
}

-- `math.huge` não sobrevive a um float32 de forma útil para contagem regressiva; o fim de fase
-- "sem prazo" viaja como este sentinela e volta a math.huge do outro lado.
local NO_DEADLINE = -1

local function packDeadline(value: number): number
	if value == math.huge or value ~= value then
		return NO_DEADLINE
	end
	return value
end

local function unpackDeadline(value: number): number
	if value == NO_DEADLINE then
		return math.huge
	end
	return value
end

-- ---------------------------------------------------------------------------
-- Snapshot
-- ---------------------------------------------------------------------------

function Codec.encodeSnapshot(snapshot: Types.MatchSnapshot): WireSnapshot
	local enemies: { WireEnemy } = {}
	for _, e in ipairs(snapshot.enemies) do
		table.insert(enemies, {
			id = e.id,
			d = Enums.toId(Enums.enemy, e.d),
			b = e.b,
			hp = e.hp,
			mhp = e.mhp,
			s = e.s,
			v = e.v,
			sl = e.sl,
			mk = e.mk,
			sm = e.sm,
			tg = e.tg,
			tga = e.tga,
			ab = e.ab,
			ar = e.ar,
			er = e.er,
		})
	end
	local towers: { WireTower } = {}
	for _, t in ipairs(snapshot.towers) do
		table.insert(towers, {
			id = t.id,
			o = t.o,
			d = Enums.toId(Enums.tower, t.d),
			st = Enums.toId(Enums.towerState, t.st),
			x = t.x,
			y = t.y,
			tm = Enums.toId(Enums.targetMode, t.tm),
			inv = t.inv,
			cp = t.cp,
			ci = Enums.toId(Enums.circuit, t.ci),
			du = t.du,
		})
	end
	local parts: { WireParticipant } = {}
	for _, p in ipairs(snapshot.participants) do
		table.insert(parts, {
			u = p.userId,
			n = p.name,
			c = p.connected,
			r = p.ready,
			sv = p.speedVote,
			col = p.color,
		})
	end
	local preview: { WireGroup } = {}
	for _, g in ipairs(snapshot.nextWavePreview or {}) do
		table.insert(preview, { e = Enums.toId(Enums.enemy, g.enemy), n = g.count })
	end
	return {
		matchId = snapshot.matchId,
		mode = Enums.toId(Enums.matchMode, snapshot.mode),
		map = Enums.toId(Enums.map, snapshot.mapId),
		diff = Enums.toId(Enums.difficulty, snapshot.difficulty),
		phase = Enums.toId(Enums.phase, snapshot.phase),
		wave = snapshot.waveIndex,
		total = snapshot.totalWaves,
		hp = snapshot.baseHP,
		t = snapshot.simTime,
		speed = snapshot.speedMultiplier,
		ends = packDeadline(snapshot.phaseEndsAt),
		pulse = packDeadline(snapshot.pulseReadyAt),
		rev = snapshot.revision,
		wallet = snapshot.wallet,
		limit = snapshot.limits.perPlayer,
		placed = snapshot.limits.placedByMe,
		full = snapshot.full,
		unlockAll = snapshot.trainingUnlockAll,
		level = if snapshot.levelId then (Catalog.levelIndex(snapshot.levelId) or 0) else 0,
		dmg = snapshot.damageTaken,
		built = snapshot.towersBuilt,
		rushed = snapshot.wavesRushed,
		enemies = enemies,
		towers = towers,
		parts = parts,
		preview = preview,
	}
end

function Codec.decodeSnapshot(wire: WireSnapshot): Types.MatchSnapshot
	local enemies: { Types.EnemySnapshot } = {}
	for _, e in ipairs(wire.enemies) do
		table.insert(enemies, {
			id = e.id,
			d = Enums.toValueOr(Enums.enemy, e.d, "fiapo"),
			b = e.b,
			hp = e.hp,
			mhp = e.mhp,
			s = e.s,
			v = e.v,
			sl = e.sl,
			mk = e.mk,
			sm = e.sm,
			tg = e.tg,
			tga = e.tga,
			ab = e.ab,
			ar = e.ar,
			er = e.er,
		})
	end
	local towers: { Types.TowerSnapshot } = {}
	for _, t in ipairs(wire.towers) do
		table.insert(towers, {
			id = t.id,
			o = t.o,
			d = Enums.toValueOr(Enums.tower, t.d, "dardo"),
			st = Enums.toValueOr(Enums.towerState, t.st, "L0"),
			x = t.x,
			y = t.y,
			tm = Enums.toValueOr(Enums.targetMode, t.tm, "first"),
			inv = t.inv,
			cp = t.cp,
			ci = Enums.toValue(Enums.circuit, t.ci),
			du = t.du,
		})
	end
	local parts: { Types.ParticipantSnapshot } = {}
	for _, p in ipairs(wire.parts) do
		table.insert(parts, {
			userId = p.u,
			name = p.n,
			connected = p.c,
			ready = p.r,
			speedVote = p.sv,
			color = p.col,
		})
	end
	local preview: { Types.WaveGroup } = {}
	for _, g in ipairs(wire.preview) do
		table.insert(preview, { enemy = Enums.toValueOr(Enums.enemy, g.e, "fiapo"), count = g.n })
	end
	return {
		matchId = wire.matchId,
		mode = Enums.toValueOr(Enums.matchMode, wire.mode, "normal") :: Types.MatchMode,
		mapId = Enums.toValueOr(Enums.map, wire.map, "jardim"),
		difficulty = Enums.toValueOr(Enums.difficulty, wire.diff, "normal") :: Types.Difficulty,
		phase = Enums.toValueOr(Enums.phase, wire.phase, "Lobby") :: Types.Phase,
		waveIndex = wire.wave,
		totalWaves = wire.total,
		baseHP = wire.hp,
		simTime = wire.t,
		speedMultiplier = wire.speed,
		phaseEndsAt = unpackDeadline(wire.ends),
		pulseReadyAt = unpackDeadline(wire.pulse),
		revision = wire.rev,
		enemies = enemies,
		towers = towers,
		participants = parts,
		wallet = wire.wallet,
		limits = { perPlayer = wire.limit, placedByMe = wire.placed },
		result = nil, -- o resultado chega no quadro "result", não no snapshot
		full = wire.full,
		nextWavePreview = if #preview > 0 then preview else nil,
		trainingUnlockAll = wire.unlockAll,
		levelId = if wire.level > 0 then levelIdByIndex(wire.level) else nil,
		damageTaken = wire.dmg,
		towersBuilt = wire.built,
		wavesRushed = wire.rushed,
	}
end

-- ---------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------

function Codec.encodeEvent(e: Types.NetEvent): WireEvent
	local kindId = Enums.toId(Enums.event, e.kind)
	local targets: { WireTarget } = {}
	for _, t in ipairs(e.targets or {}) do
		table.insert(targets, { e = t.enemyId, d = t.damage, i = t.index })
	end
	local cell = e.cell
	return {
		k = kindId,
		ks = if kindId == 0 then e.kind else nil,
		t = e.simTime,
		entity = e.entityId,
		tower = e.towerId,
		seq = e.attackSeq,
		user = e.userId,
		amount = e.amount,
		wave = e.wave,
		phase = if e.phase then Enums.toId(Enums.phase, e.phase) else nil,
		enemyDef = if e.enemyDefId then Enums.toId(Enums.enemy, e.enemyDefId) else nil,
		circuit = if e.circuitId then Enums.toId(Enums.circuit, e.circuitId) else nil,
		partner = e.partnerId,
		radius = e.radius,
		s = e.s,
		resolveAt = e.resolveAt,
		expiresAt = e.expiresAt,
		cellX = if cell then cell[1] else nil,
		cellY = if cell then cell[2] else nil,
		reason = e.reason,
		code = e.code,
		speed = e.speed,
		targets = targets,
		entityIds = e.entityIds or {},
		towerIds = e.towerIds or {},
	}
end

function Codec.decodeEvent(wire: WireEvent): Types.NetEvent
	local targets: { Types.AttackTarget } = {}
	for _, t in ipairs(wire.targets) do
		table.insert(targets, { enemyId = t.e, damage = t.d, index = t.i })
	end
	local cell: Types.Cell? = nil
	if wire.cellX ~= nil and wire.cellY ~= nil then
		cell = { wire.cellX :: number, wire.cellY :: number }
	end
	return {
		kind = Enums.toValue(Enums.event, wire.k) or wire.ks or "unknown",
		simTime = wire.t,
		entityId = wire.entity,
		towerId = wire.tower,
		attackSeq = wire.seq,
		targets = if #targets > 0 then targets else nil,
		enemyDefId = if wire.enemyDef then Enums.toValue(Enums.enemy, wire.enemyDef :: number) else nil,
		userId = wire.user,
		amount = wire.amount,
		wave = wire.wave,
		phase = if wire.phase then Enums.toValue(Enums.phase, wire.phase :: number) :: Types.Phase? else nil,
		cell = cell,
		circuitId = if wire.circuit then Enums.toValue(Enums.circuit, wire.circuit :: number) else nil,
		partnerId = wire.partner,
		reason = wire.reason,
		radius = wire.radius,
		s = wire.s,
		code = wire.code,
		speed = wire.speed,
		resolveAt = wire.resolveAt,
		expiresAt = wire.expiresAt,
		entityIds = if #wire.entityIds > 0 then wire.entityIds else nil,
		towerIds = if #wire.towerIds > 0 then wire.towerIds else nil,
	}
end

function Codec.encodeEvents(events: { Types.NetEvent }): { WireEvent }
	local out: { WireEvent } = {}
	for _, e in ipairs(events) do
		table.insert(out, Codec.encodeEvent(e))
	end
	return out
end

function Codec.decodeEvents(wire: { WireEvent }): { Types.NetEvent }
	local out: { Types.NetEvent } = {}
	for _, e in ipairs(wire) do
		table.insert(out, Codec.decodeEvent(e))
	end
	return out
end

return Codec
