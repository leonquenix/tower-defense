--!strict
-- Execução no servidor. O XP é do perfil; o console só pede.
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.Server.Services.MatchService)

return function(context: any, amount: number): string
	local ok, message = MatchService.cheatAddXp(context.Executor, amount)
	return if ok then message else "Recusado: " .. message
end
