--!strict
-- Execução no servidor.
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.Server.Services.MatchService)

return function(context: any): string
	local ok, message = MatchService.cheatFinish(context.Executor, "lost", nil)
	return if ok then message else "Recusado: " .. message
end
