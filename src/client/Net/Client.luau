--!strict
-- Cliente de rede sobre ByteNet: envia intenções com requestId e sequência de sessão e espera
-- a resposta correlacionada. Recebe quadros da partida (já decodificados por Net/Codec) e avisos
-- de lobby.
--
-- O transporte deixou de ser RemoteFunction: um pacote `command` sai e um pacote `result` volta
-- com o mesmo requestId. Quem chama continua vendo uma chamada que espera a resposta; a diferença
-- é que agora existe prazo (RESPONSE_TIMEOUT) em vez de travar a thread até o servidor responder.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codec = require(ReplicatedStorage.Shared.Net.Codec)
local Enums = require(ReplicatedStorage.Shared.Net.Enums)
local Packets = require(ReplicatedStorage.Shared.Net.Packets)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)

local Client = {}

Client.RESPONSE_TIMEOUT = 10 -- segundos antes de desistir de uma resposta

export type Response = { [string]: any }

type Waiting = {
	thread: thread?,
	response: Response?,
	completed: boolean,
}

local sequence = 0
local waiting: { [string]: Waiting } = {}
local pendingCount = 0

local stateListeners: { (kind: string, payload: any, extra: any) -> () } = {}
local lobbyListeners: { (kind: string, payload: any) -> () } = {}

local function finish(id: string, response: Response)
	local slot = waiting[id]
	if not slot or slot.completed then
		return
	end
	slot.completed = true
	slot.response = response
	local thread = slot.thread
	slot.thread = nil
	if thread and coroutine.status(thread) == "suspended" then
		task.spawn(thread, response)
	end
end

Packets.result.listen(function(data: { id: string, ok: boolean, code: string?, body: any })
	local body: Response = if typeof(data.body) == "table" then data.body else {}
	body.ok = data.ok
	body.errorCode = data.code
	body.requestId = data.id
	finish(data.id, body)
end)

Packets.frame.listen(function(data: { snap: any, events: { any } })
	local snapshot = Codec.decodeSnapshot(data.snap)
	local events = Codec.decodeEvents(data.events)
	for _, fn in ipairs(stateListeners) do
		task.spawn(fn, "frame", snapshot, events)
	end
end)

Packets.matchInfo.listen(function(data: { kind: number, data: any })
	local kind = Enums.toValue(Enums.frame, data.kind)
	if not kind then
		return
	end
	local body = if typeof(data.data) == "table" then data.data else {}
	for _, fn in ipairs(stateListeners) do
		task.spawn(fn, kind, body.p, body.e)
	end
end)

Packets.lobby.listen(function(data: { kind: number, data: any })
	local kind = Enums.toValue(Enums.lobby, data.kind)
	if not kind then
		return
	end
	for _, fn in ipairs(lobbyListeners) do
		task.spawn(fn, kind, data.data)
	end
end)

-- Envia um comando e espera a resposta. Repetições podem reusar o mesmo requestId: o servidor
-- devolve a resposta guardada em vez de aplicar a ação duas vezes (Protocol.checkDedupe).
function Client.request(action: string, payload: { [string]: any }?, requestId: string?): Response
	sequence += 1
	local id = requestId or (HttpService:GenerateGUID(false):sub(1, 12) .. "-" .. tostring(sequence))
	local slot: Waiting = { thread = coroutine.running(), response = nil, completed = false }
	waiting[id] = slot
	pendingCount += 1
	local ok, err = pcall(function()
		Packets.command.send({
			seq = sequence,
			id = id,
			action = action,
			payload = payload or {},
		})
	end)
	if not ok then
		waiting[id] = nil
		pendingCount -= 1
		return { ok = false, errorCode = Protocol.ERROR.BAD_REQUEST, requestId = id, transport = tostring(err) }
	end
	task.delay(Client.RESPONSE_TIMEOUT, function()
		finish(id, { ok = false, errorCode = Protocol.ERROR.RATE_LIMIT, requestId = id, timedOut = true })
	end)
	local response: Response = coroutine.yield()
	waiting[id] = nil
	pendingCount -= 1
	return response
end

function Client.requestAsync(action: string, payload: { [string]: any }?, callback: ((Response) -> ())?)
	task.spawn(function()
		local response = Client.request(action, payload)
		if callback then
			callback(response)
		end
	end)
end

function Client.onState(fn: (kind: string, payload: any, extra: any) -> ())
	table.insert(stateListeners, fn)
end

function Client.onLobby(fn: (kind: string, payload: any) -> ())
	table.insert(lobbyListeners, fn)
end

function Client.hasPending(): boolean
	return pendingCount > 0
end

return Client
