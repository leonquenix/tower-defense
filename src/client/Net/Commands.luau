--!strict
-- Intenções da interface -> servidor. Uma única porta de saída para comandos.
--
-- Regras mantidas do guia:
--  * um pedido pendente por chave: dez toques em 500 ms de latência viram uma ação só;
--  * a repetição preserva o requestId — o servidor deduplica e devolve a resposta original,
--    então nenhuma compra é cobrada duas vezes;
--  * fechar a tela não cancela um comando aceito: a resposta continua atualizando o estado;
--  * até 1 s a interface só mostra que o toque foi recebido, em 1 s "confirmando", em 5 s
--    "demorando" — nunca "falhou" por conta própria.
--
-- O que mudou no revamp: as pendências vivem num átomo Charm, então um botão pode simplesmente
-- ler `Commands.isPendingState(key)` e se desabilitar sozinho.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Shared.Lib.Charm)
local Actions = require(script.Parent.Parent.State.Actions)
local Client = require(script.Parent.Client)

local Commands = {}

export type Stage = "sent" | "confirming" | "slow"

export type Handlers = {
	onStage: ((stage: Stage) -> ())?,
	onSuccess: ((response: Client.Response) -> ())?,
	onError: ((code: string, response: Client.Response) -> ())?,
}

export type Pending = {
	key: string,
	action: string,
	payload: { [string]: any },
	requestId: string,
	startedAt: number,
	stage: Stage,
}

local CONFIRMING_AFTER = 1
local SLOW_AFTER = 5

Commands.pending = Charm.atom({} :: { [string]: Pending })

local handlersByKey: { [string]: Handlers } = {}
local observers: { (action: string, response: Client.Response) -> () } = {}
local revisionSeen = -1

local function setPending(key: string, entry: Pending?)
	local copy: { [string]: Pending } = table.clone(Commands.pending())
	if entry then
		copy[key] = entry
	else
		copy[key] = nil
	end
	Commands.pending(copy)
end

local function newRequestId(): string
	return string.format("%s-%d", tostring(math.random(0, 0xFFFFFF)), os.clock() * 1000 // 1)
end

function Commands.isPending(key: string): boolean
	return Commands.pending()[key] ~= nil
end

function Commands.pendingOf(key: string): Pending?
	return Commands.pending()[key]
end

function Commands.observe(fn: (action: string, response: Client.Response) -> ())
	table.insert(observers, fn)
end

function Commands.revision(): number
	return revisionSeen
end

local function setStage(key: string, stage: Stage)
	local entry = Commands.pending()[key]
	if not entry or entry.stage == stage then
		return
	end
	local updated = table.clone(entry)
	updated.stage = stage
	setPending(key, updated)
	local handlers = handlersByKey[key]
	if handlers and handlers.onStage then
		handlers.onStage(stage)
	end
end

local function dispatch(entry: Pending)
	local key = entry.key
	task.spawn(function()
		local response = Client.request(entry.action, entry.payload, entry.requestId)
		if typeof(response.revision) == "number" and response.revision > revisionSeen then
			revisionSeen = response.revision
		end
		-- perfil novo em qualquer resposta atualiza o estado global, mesmo sem tela aberta
		if response.ok and typeof(response.profile) == "table" then
			Actions.setProfile(response.profile)
		end
		for _, observer in ipairs(observers) do
			task.spawn(observer, entry.action, response)
		end
		if Commands.pending()[key] == entry then
			setPending(key, nil)
		end
		local handlers = handlersByKey[key]
		handlersByKey[key] = nil
		if not handlers then
			return
		end
		if response.ok then
			if handlers.onSuccess then
				handlers.onSuccess(response)
			end
		elseif handlers.onError then
			handlers.onError(tostring(response.errorCode or "INVALID_STATE"), response)
		end
	end)

	task.delay(CONFIRMING_AFTER, function()
		if Commands.pending()[key] == entry then
			setStage(key, "confirming")
		end
	end)
	task.delay(SLOW_AFTER, function()
		if Commands.pending()[key] == entry then
			setStage(key, "slow")
		end
	end)
end

-- Envia uma intenção. Devolve false quando já existe um pedido pendente com a mesma chave.
function Commands.send(key: string, action: string, payload: { [string]: any }?, handlers: Handlers?): boolean
	if Commands.isPending(key) then
		return false
	end
	local entry: Pending = {
		key = key,
		action = action,
		payload = payload or {},
		requestId = newRequestId(),
		startedAt = os.clock(),
		stage = "sent",
	}
	setPending(key, entry)
	handlersByKey[key] = handlers or {}
	if handlers and handlers.onStage then
		handlers.onStage("sent")
	end
	dispatch(entry)
	return true
end

-- Reconciliação: repete o MESMO requestId em vez de criar outro pedido.
function Commands.reconcile(key: string, handlers: Handlers?): boolean
	local entry = Commands.pending()[key]
	if not entry then
		return false
	end
	if handlers then
		handlersByKey[key] = handlers
	end
	dispatch(entry)
	return true
end

-- Desliga só os callbacks de tela (os observadores globais continuam recebendo).
function Commands.detach(key: string)
	handlersByKey[key] = nil
end

function Commands.clearScreen(prefix: string)
	for key in pairs(handlersByKey) do
		if key:sub(1, #prefix) == prefix then
			handlersByKey[key] = nil
		end
	end
end

return Commands
