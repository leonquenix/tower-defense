--!strict
-- Execução no servidor. A carteira é do servidor; o console só pede.
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.Server.Services.MatchService)

return function(context: any, amount: number): string
	local ok, message = MatchService.cheatSetScrap(context.Executor, amount)
	return if ok then message else "Recusado: " .. message
end
