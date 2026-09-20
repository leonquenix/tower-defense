--!strict
-- Execução no servidor. As estrelas entram no perfil pelo mesmo caminho de uma vitória de
-- verdade: o laço da partida vê o resultado pronto, paga e salva.
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.Server.Services.MatchService)

return function(context: any, stars: number?): string
	local ok, message = MatchService.cheatFinish(context.Executor, "won", stars or 3)
	return if ok then message else "Recusado: " .. message
end
