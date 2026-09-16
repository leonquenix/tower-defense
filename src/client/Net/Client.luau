--!strict
-- Cliente de rede: envia intenções com requestId e sequência; recebe frames e eventos de lobby.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)

local Client = {}

local folder = ReplicatedStorage:WaitForChild(Protocol.REMOTE_FOLDER, 30) :: Folder
assert(folder, "remotes não encontrados")
local commandRemote = folder:WaitForChild(Protocol.COMMAND_REMOTE) :: RemoteFunction
local stateRemote = folder:WaitForChild(Protocol.STATE_REMOTE) :: RemoteEvent
local lobbyRemote = folder:WaitForChild(Protocol.LOBBY_REMOTE) :: RemoteEvent

local sequence = 0
local pending: { [string]: boolean } = {}

export type Response = { [string]: any }

-- Envia um comando e aguarda a resposta. Repetições usam o mesmo requestId.
function Client.request(action: string, payload: { [string]: any }?, requestId: string?): Response
	sequence += 1
	local id = requestId or (HttpService:GenerateGUID(false):sub(1, 12) .. "-" .. tostring(sequence))
	local envelope = {
		protocolVersion = Protocol.VERSION,
		sessionSequence = sequence,
		requestId = id,
		action = action,
		payload = payload or {},
	}
	pending[id] = true
	local ok, response = pcall(function()
		return commandRemote:InvokeServer(envelope)
	end)
	pending[id] = nil
	if not ok then
		return { ok = false, errorCode = "INVALID_STATE", requestId = id, transport = tostring(response) }
	end
	if typeof(response) ~= "table" then
		return { ok = false, errorCode = "BAD_REQUEST", requestId = id }
	end
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

function Client.onState(fn: (kind: string, payload: any, extra: any) -> ()): RBXScriptConnection
	return stateRemote.OnClientEvent:Connect(fn)
end

function Client.onLobby(fn: (kind: string, payload: any) -> ()): RBXScriptConnection
	return lobbyRemote.OnClientEvent:Connect(fn)
end

function Client.hasPending(): boolean
	return next(pending) ~= nil
end

return Client
