--!strict
-- Contrato de rede: nomes de ações, códigos de erro e validação de forma dos payloads.
--
-- O transporte é ByteNet (Net/Packets); aqui ficam só as regras puras, testáveis fora do Studio:
-- validação de envelope, limites de taxa por balde e janela de deduplicação por requestId.
-- Validação rejeita campos desconhecidos, strings longas, NaN e infinitos antes de qualquer
-- operação custosa.
local Protocol = {}

Protocol.VERSION = 1
Protocol.MAX_REQUEST_ID = 40
Protocol.MAX_STRING = 64
Protocol.MAX_DEPTH = 3
Protocol.RESPONSE_CACHE = 128

Protocol.ERROR = {
	INVALID_CELL = "INVALID_CELL",
	OCCUPIED = "OCCUPIED",
	NOT_OWNER = "NOT_OWNER",
	INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS",
	LIMIT_REACHED = "LIMIT_REACHED",
	INVALID_STATE = "INVALID_STATE",
	PROFILE_UNAVAILABLE = "PROFILE_UNAVAILABLE",
	RATE_LIMIT = "RATE_LIMIT",
	STALE_REQUEST = "STALE_REQUEST",
	BAD_REQUEST = "BAD_REQUEST",
	NOT_IN_MATCH = "NOT_IN_MATCH",
	SHOP_DISABLED = "SHOP_DISABLED",
}

export type FieldSpec = { kind: "string" | "int" | "number" | "boolean" | "stringList", optional: boolean?, max: number? }

-- Ações e payloads permitidos. Qualquer campo fora da lista é recusado.
local ACTIONS: { [string]: { [string]: FieldSpec } } = {
	PlaceTower = {
		matchId = { kind = "string" },
		towerId = { kind = "string" },
		x = { kind = "int" },
		y = { kind = "int" },
	},
	UpgradeTower = { matchId = { kind = "string" }, entityId = { kind = "int" }, nextState = { kind = "string" } },
	SellTower = { matchId = { kind = "string" }, entityId = { kind = "int" } },
	SetTarget = { matchId = { kind = "string" }, entityId = { kind = "int" }, mode = { kind = "string" } },
	CastPulse = { matchId = { kind = "string" } },
	SetReady = { matchId = { kind = "string" }, ready = { kind = "boolean" } },
	VoteSpeed = { matchId = { kind = "string" }, value = { kind = "int" } },
	RequestSnapshot = { matchId = { kind = "string" } },
	LeaveMatch = { matchId = { kind = "string" } },
	TrainingSpawn = { matchId = { kind = "string" }, enemyId = { kind = "string" }, count = { kind = "int" } },
	TrainingClear = { matchId = { kind = "string" } },
	TutorialAdvance = { matchId = { kind = "string" }, step = { kind = "int" } },
	TutorialSkip = { matchId = { kind = "string" } },
	SetLoadout = { towerIds = { kind = "stringList", max = 4 } },
	BuyTower = { towerId = { kind = "string" } },
	StartMatch = {
		partyId = { kind = "string", optional = true },
		mapId = { kind = "string" },
		mode = { kind = "string" },
		matchMode = { kind = "string", optional = true },
	},
	CreateParty = {},
	JoinParty = { partyId = { kind = "string" } },
	LeaveParty = {},
	InviteToParty = { userId = { kind = "int" } },
	-- Resposta a um convite recebido. O inviteId é o token emitido pelo servidor: sem ele,
	-- ou com ele vencido, nenhuma entrada acontece.
	RespondInvite = { inviteId = { kind = "string" }, accept = { kind = "boolean" } },
	KickFromParty = { userId = { kind = "int" } },
	PartyReady = { ready = { kind = "boolean" } },
	PartySetup = { mapId = { kind = "string" }, mode = { kind = "string" } },
	Rematch = { matchId = { kind = "string" }, ready = { kind = "boolean" } },
	SaveSettings = {
		musicVolume = { kind = "number" },
		sfxVolume = { kind = "number" },
		reducedMotion = { kind = "boolean" },
		reducedParticles = { kind = "boolean" },
		damageNumbers = { kind = "boolean" },
		circuitPattern = { kind = "string" },
		locale = { kind = "string" },
	},
	EquipCosmetic = { slot = { kind = "string" }, cosmeticId = { kind = "string" } },
	QueryShop = {},
	PromptFounderPass = {},
	ClaimPending = {},
	RetryProfile = {},
	Telemetry = { event = { kind = "string" }, value = { kind = "number", optional = true } },
	DevCommand = {
		matchId = { kind = "string", optional = true },
		command = { kind = "string" },
		arg = { kind = "number", optional = true },
	},
}

-- Ações de combate sujeitas ao limite de dez por segundo (rajada vinte)
local COMBAT_ACTIONS: { [string]: boolean } = {
	PlaceTower = true,
	UpgradeTower = true,
	SellTower = true,
	SetTarget = true,
	CastPulse = true,
	SetReady = true,
	VoteSpeed = true,
	TrainingSpawn = true,
	TrainingClear = true,
	TutorialAdvance = true,
	TutorialSkip = true,
	Rematch = true,
	LeaveMatch = true,
	Telemetry = true,
}
-- Compras persistentes: uma por segundo, rajada de duas
local PERSISTENT_ACTIONS: { [string]: boolean } = {
	BuyTower = true,
	SetLoadout = true,
	SaveSettings = true,
	EquipCosmetic = true,
	PromptFounderPass = true,
	ClaimPending = true,
	RetryProfile = true,
	-- convites gastam o balde persistente: o cooldown de 5 s por destinatário é do PartyService
	InviteToParty = true,
	RespondInvite = true,
}
-- Snapshot completo: um a cada dois segundos
local SNAPSHOT_ACTIONS: { [string]: boolean } = { RequestSnapshot = true }

Protocol.ACTIONS = ACTIONS
Protocol.COMBAT_ACTIONS = COMBAT_ACTIONS
Protocol.PERSISTENT_ACTIONS = PERSISTENT_ACTIONS
Protocol.SNAPSHOT_ACTIONS = SNAPSHOT_ACTIONS

local function isFiniteNumber(v: any): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function validField(value: any, spec: FieldSpec): boolean
	if spec.kind == "string" then
		return typeof(value) == "string" and #value <= (spec.max or Protocol.MAX_STRING)
	elseif spec.kind == "int" then
		return isFiniteNumber(value) and math.floor(value) == value and math.abs(value) < 2 ^ 40
	elseif spec.kind == "number" then
		return isFiniteNumber(value) and math.abs(value) < 2 ^ 40
	elseif spec.kind == "boolean" then
		return typeof(value) == "boolean"
	elseif spec.kind == "stringList" then
		if typeof(value) ~= "table" then
			return false
		end
		local n = 0
		for k, v in pairs(value) do
			n += 1
			if typeof(k) ~= "number" or typeof(v) ~= "string" or #v > Protocol.MAX_STRING then
				return false
			end
		end
		return n <= (spec.max or 8) and #value == n
	end
	return false
end

export type Envelope = {
	protocolVersion: number,
	sessionSequence: number,
	requestId: string,
	action: string,
	payload: { [string]: any },
}

-- Valida o envelope completo. Retorna (envelope tipado, nil) ou (nil, código de erro).
function Protocol.validateEnvelope(raw: any): (Envelope?, string?)
	if typeof(raw) ~= "table" then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	local count = 0
	for _ in pairs(raw) do
		count += 1
	end
	if count ~= 5 then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	if raw.protocolVersion ~= Protocol.VERSION then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	if
		not (
			isFiniteNumber(raw.sessionSequence)
			and math.floor(raw.sessionSequence) == raw.sessionSequence
			and raw.sessionSequence >= 0
		)
	then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	if typeof(raw.requestId) ~= "string" or #raw.requestId == 0 or #raw.requestId > Protocol.MAX_REQUEST_ID then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	if typeof(raw.action) ~= "string" then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	local schema = ACTIONS[raw.action]
	if not schema then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	local payload = raw.payload
	if typeof(payload) ~= "table" then
		return nil, Protocol.ERROR.BAD_REQUEST
	end
	for key, value in pairs(payload) do
		if typeof(key) ~= "string" then
			return nil, Protocol.ERROR.BAD_REQUEST
		end
		local spec = schema[key]
		if not spec then
			return nil, Protocol.ERROR.BAD_REQUEST
		end
		if not validField(value, spec) then
			return nil, Protocol.ERROR.BAD_REQUEST
		end
	end
	for key, spec in pairs(schema) do
		if payload[key] == nil and not spec.optional then
			return nil, Protocol.ERROR.BAD_REQUEST
		end
	end
	return {
		protocolVersion = raw.protocolVersion,
		sessionSequence = raw.sessionSequence,
		requestId = raw.requestId,
		action = raw.action,
		payload = payload,
	},
		nil
end

-- Limitador de taxa por balde (token bucket). Puro: recebe o relógio.
export type Bucket = { tokens: number, last: number, rate: number, burst: number }

function Protocol.newBucket(rate: number, burst: number, now: number): Bucket
	return { tokens = burst, last = now, rate = rate, burst = burst }
end

function Protocol.takeToken(bucket: Bucket, now: number): boolean
	local elapsed = math.max(0, now - bucket.last)
	bucket.last = now
	bucket.tokens = math.min(bucket.burst, bucket.tokens + elapsed * bucket.rate)
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

-- Janela de deduplicação por sessão: guarda respostas recentes e a maior sequência aceita.
export type DedupeWindow = {
	responses: { [string]: any },
	order: { string },
	highestSequence: number,
}

function Protocol.newDedupe(): DedupeWindow
	return { responses = {}, order = {}, highestSequence = -1 }
end

-- Retorna (resposta anterior, nil) quando repetido; (nil, STALE_REQUEST) se fora da janela; (nil, nil) se novo.
function Protocol.checkDedupe(window: DedupeWindow, requestId: string, sequence: number): (any?, string?)
	local previous = window.responses[requestId]
	if previous ~= nil then
		return previous, nil
	end
	if sequence <= window.highestSequence - Protocol.RESPONSE_CACHE then
		return nil, Protocol.ERROR.STALE_REQUEST
	end
	return nil, nil
end

function Protocol.remember(window: DedupeWindow, requestId: string, sequence: number, response: any)
	if window.responses[requestId] == nil then
		table.insert(window.order, requestId)
		if #window.order > Protocol.RESPONSE_CACHE then
			local oldest = table.remove(window.order, 1) :: string
			window.responses[oldest] = nil
		end
	end
	window.responses[requestId] = response
	if sequence > window.highestSequence then
		window.highestSequence = sequence
	end
end

return Protocol
