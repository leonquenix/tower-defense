--!strict
-- Execução no servidor. Quem declara a derrota continua sendo o passo da simulação.
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.Server.Services.MatchService)

return function(context: any, health: number): string
	local ok, message = MatchService.cheatSetBaseHP(context.Executor, health)
	return if ok then message else "Recusado: " .. message
end
