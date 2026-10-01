--!strict
-- Execução no servidor. O inventário é do perfil; o console só pede.
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.Server.Services.MatchService)

return function(context: any, item: string, amount: number?): string
	local ok, message = MatchService.cheatGrantItem(context.Executor, item, amount or 1)
	return if ok then message else "Recusado: " .. message
end
