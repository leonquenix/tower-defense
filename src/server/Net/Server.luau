--!strict
-- Fachada de rede do servidor sobre ByteNet. Os serviços não conhecem pacotes nem buffers:
-- mandam snapshot, aviso ou resposta e este módulo cuida da codificação (Net/Codec) e dos ids.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local Codec = require(ReplicatedStorage.Shared.Net.Codec)
local Enums = require(ReplicatedStorage.Shared.Net.Enums)
local Packets = require(ReplicatedStorage.Shared.Net.Packets)

local Server = {}

-- O ByteNet só cria o canal de um jogador no próprio Players.PlayerAdded dele. Um envio que
-- acontece antes disso (o primeiro lobby, no arranque do servidor) estoura dentro do pacote.
-- Em vez de espalhar pcall pelos serviços, o envio que falha volta para esta fila e é repetido
-- no próximo Heartbeat. Depois de MAX_RETRIES o pacote é descartado com aviso: melhor perder um
-- quadro do que empilhar mensagens velhas.
local MAX_RETRIES = 5

type Outgoing = { send: () -> (), player: Player, attempts: number, label: string }

local outbox: { Outgoing } = {}

local function deliver(player: Player, label: string, send: () -> ())
	-- O primeiro envio a um jogador recém-entrado quase sempre cai aqui (o ByteNet ainda não
	-- criou o canal dele): é esperado e resolvido no Heartbeat seguinte, sem aviso no console.
	if pcall(send) then
		return
	end
	table.insert(outbox, { send = send, player = player, attempts = 1, label = label })
end

RunService.Heartbeat:Connect(function()
	if #outbox == 0 then
		return
	end
	local pending = outbox
	outbox = {}
	for _, entry in ipairs(pending) do
		if entry.player.Parent == Players then
			local ok = pcall(entry.send)
			if not ok then
				entry.attempts += 1
				if entry.attempts <= MAX_RETRIES then
					table.insert(outbox, entry)
				else
					warn(`pacote descartado depois de {MAX_RETRIES} tentativas: {entry.label}`)
				end
			end
		end
	end
end)

export type Command = {
	seq: number,
	id: string,
	action: string,
	payload: { [string]: any },
}

-- Quadro de partida (10 Hz): snapshot + eventos cosméticos do intervalo.
function Server.sendFrame(player: Player, snapshot: Types.MatchSnapshot, events: { Types.NetEvent })
	local payload = { snap = Codec.encodeSnapshot(snapshot), events = Codec.encodeEvents(events) }
	deliver(player, "frame", function()
		Packets.frame.sendTo(payload, player)
	end)
end

-- Aviso raro da partida: "match", "tutorial", "result", "left", "rematch".
-- "match" reusa o quadro completo para o cliente montar a partida do zero.
function Server.sendMatchInfo(player: Player, kind: string, payload: any, extra: any?)
	local id = Enums.toId(Enums.frame, kind)
	if id == 0 then
		warn(`aviso de partida desconhecido: {kind}`)
		return
	end
	deliver(player, `matchInfo:{kind}`, function()
		Packets.matchInfo.sendTo({ kind = id, data = { p = payload, e = extra } }, player)
	end)
end

function Server.sendLobby(player: Player, kind: string, data: any)
	local id = Enums.toId(Enums.lobby, kind)
	if id == 0 then
		warn(`aviso de lobby desconhecido: {kind}`)
		return
	end
	deliver(player, `lobby:{kind}`, function()
		Packets.lobby.sendTo({ kind = id, data = data }, player)
	end)
end

-- Resposta correlacionada pelo requestId que o cliente mandou.
function Server.respond(player: Player, requestId: string, body: { [string]: any })
	local ok = body.ok == true
	local code = body.errorCode
	deliver(player, "result", function()
		Packets.result.sendTo({
			id = requestId,
			ok = ok,
			code = if typeof(code) == "string" then code else nil,
			body = body,
		}, player)
	end)
end

function Server.onCommand(handler: (player: Player, command: Command) -> ())
	Packets.command.listen(function(data: any, player: Player?)
		if typeof(data) ~= "table" or player == nil then
			return
		end
		handler(player :: Player, {
			seq = data.seq,
			id = data.id,
			action = data.action,
			payload = if typeof(data.payload) == "table" then data.payload else {},
		})
	end)
end

return Server
