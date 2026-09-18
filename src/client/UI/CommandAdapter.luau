--!strict
-- Ponte entre intenções da interface e o protocolo existente
-- ({protocolVersion, sessionSequence, requestId, action, payload}).
--
-- Regras do guia aplicadas aqui:
--  * um pedido pendente por chave de ação: dez cliques em 500 ms de latência viram uma ação;
--  * o requestId é preservado numa reconciliação — nunca reenviar compra com um id novo;
--  * até 1 s a UI só mostra que o toque foi recebido; em 1 s, "Confirmando"; em 5 s, "demorando",
--    sem presumir falha;
--  * fechar a tela não cancela um comando já aceito: a resposta atualiza o store mesmo assim;
--  * revisões antigas são ignoradas, mas o resultado de uma transação válida nunca é descartado.
local Client = require(script.Parent.Parent.Net.Client)

local CommandAdapter = {}

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

local pending: { [string]: Pending } = {}
local handlersByKey: { [string]: Handlers } = {}
local revisionSeen = -1
-- Observadores globais: recebem toda resposta, mesmo quando a tela de origem já fechou.
local observers: { (action: string, response: Client.Response) -> () } = {}

local function newRequestId(): string
	-- o Client gera o id quando não recebe um; aqui geramos para poder repetir o mesmo
	return string.format("%s-%d", tostring(math.random(0, 0xFFFFFF)), os.clock() * 1000 // 1)
end

function CommandAdapter.isPending(key: string): boolean
	return pending[key] ~= nil
end

function CommandAdapter.pendingOf(key: string): Pending?
	return pending[key]
end

function CommandAdapter.observe(fn: (action: string, response: Client.Response) -> ())
	table.insert(observers, fn)
end

-- Revisão mais recente vista em respostas; snapshots antigos não devem sobrescrever a tela.
function CommandAdapter.revision(): number
	return revisionSeen
end

local function setStage(key: string, stage: Stage)
	local entry = pending[key]
	if not entry or entry.stage == stage then
		return
	end
	entry.stage = stage
	local handlers = handlersByKey[key]
	if handlers and handlers.onStage then
		handlers.onStage(stage)
	end
end

local function dispatch(entry: Pending)
	local key = entry.key
	task.spawn(function()
		local response = Client.request(entry.action, entry.payload, entry.requestId)
		-- a resposta chega mesmo se a tela fechou: primeiro o store global, depois a tela
		if typeof(response) == "table" and typeof(response.revision) == "number" then
			if response.revision > revisionSeen then
				revisionSeen = response.revision
			end
		end
		for _, observer in ipairs(observers) do
			task.spawn(observer, entry.action, response)
		end
		if pending[key] == entry then
			pending[key] = nil
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
		if pending[key] == entry then
			setStage(key, "confirming")
		end
	end)
	task.delay(SLOW_AFTER, function()
		if pending[key] == entry then
			setStage(key, "slow")
		end
	end)
end

-- Envia uma intenção. Devolve false quando já existe um pedido pendente com a mesma chave.
function CommandAdapter.send(
	key: string,
	action: string,
	payload: { [string]: any }?,
	handlers: Handlers?
): (boolean, Pending?)
	if pending[key] then
		return false, pending[key]
	end
	local entry: Pending = {
		key = key,
		action = action,
		payload = payload or {},
		requestId = newRequestId(),
		startedAt = os.clock(),
		stage = "sent",
	}
	pending[key] = entry
	handlersByKey[key] = handlers or {}
	if handlers and handlers.onStage then
		handlers.onStage("sent")
	end
	dispatch(entry)
	return true, entry
end

-- Reconciliação: repete o MESMO requestId. O servidor deduplica e devolve a resposta original,
-- então nenhum gasto é duplicado. Usado por "Verificar novamente" e pela volta da conexão.
function CommandAdapter.reconcile(key: string, handlers: Handlers?): boolean
	local entry = pending[key]
	if not entry then
		return false
	end
	if handlers then
		handlersByKey[key] = handlers
	end
	dispatch(entry)
	return true
end

-- Desliga apenas os callbacks de tela (a resposta continua indo para os observadores globais).
function CommandAdapter.detach(key: string)
	handlersByKey[key] = nil
end

function CommandAdapter.clearScreen(prefix: string)
	for key in pairs(handlersByKey) do
		if key:sub(1, #prefix) == prefix then
			handlersByKey[key] = nil
		end
	end
end

return CommandAdapter
