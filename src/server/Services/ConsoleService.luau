--!strict
-- Console de teste sobre o Cmdr. Abre com F2 e existe só para depurar a partida: dar sucata,
-- mexer na vida do Farol e forçar o fim da fase com as estrelas que se quer conferir.
--
-- Nada aqui é regra de jogo. Toda ordem do console cai nas funções `cheat*` do MatchService, que
-- continuam validando estado e permissão — o console não escreve no estado da partida.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DevFlags = require(ReplicatedStorage.Shared.Config.DevFlags)
local MatchService = require(script.Parent.MatchService)
local TelemetryService = require(script.Parent.TelemetryService)

local ConsoleService = {}

local started = false

function ConsoleService.init()
	if not DevFlags.testConsole or started then
		return
	end
	started = true

	-- O Cmdr é dependência de servidor: a biblioteca não é replicada, só a interface que ela
	-- mesma publica em ReplicatedStorage (CmdrClient) e as definições dos comandos.
	local Cmdr = require(ServerScriptService.ServerPackages.Cmdr) :: any

	-- Sem um gancho BeforeRun o próprio Cmdr recusa tudo fora do Studio. A regra é a mesma do
	-- DevCommand: Studio ou lista de desenvolvedores.
	Cmdr.Registry:RegisterHook("BeforeRun", function(context: any): string?
		if MatchService.isDevAllowed(context.Executor) then
			return nil
		end
		return "Console de teste indisponível para este jogador."
	end)

	Cmdr.Registry:RegisterCommandsIn(script.Parent.Parent.Console.Commands)
	-- Só o `help` das embutidas: as outras (matar, teleportar, dar ferramenta) pressupõem
	-- avatar, e aqui não existe avatar nenhum.
	Cmdr.Registry:RegisterDefaultCommands({ "Help" })

	TelemetryService.log("console_ready", { commands = #Cmdr.Registry:GetCommandNames() })
end

return ConsoleService
