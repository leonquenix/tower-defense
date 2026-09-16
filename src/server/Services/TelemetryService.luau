--!strict
-- Telemetria estruturada: eventos com versão, matchId, modo, mapa, onda e grupo. Falhas nunca interrompem o jogo.
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Balance = require(game:GetService("ReplicatedStorage").Shared.Config.Balance)

local TelemetryService = {}

local BUILD = "qeg-v1-" .. Balance.checksum:sub(1, 8)
local RING_SIZE = 400
local ring: { { [string]: any } } = {}

export type Fields = { [string]: any }

function TelemetryService.log(event: string, fields: Fields?)
	local entry: Fields = { event = event, build = BUILD, at = os.time() }
	if fields then
		for k, v in pairs(fields) do
			entry[k] = v
		end
	end
	table.insert(ring, entry)
	if #ring > RING_SIZE then
		table.remove(ring, 1)
	end
	if RunService:IsStudio() then
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(entry)
		end)
		print("[telemetria]", if ok then encoded else event)
	end
end

-- Funil de progressão. Só envia quando fora do Studio; sempre em pcall.
function TelemetryService.funnel(player: Player, funnelName: string, step: number, stepName: string, sessionId: string?)
	TelemetryService.log("funnel", { userId = player.UserId, funnel = funnelName, step = step, stepName = stepName })
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId or "", step, stepName)
		end)
	end)
end

function TelemetryService.recent(count: number?): { Fields }
	local n = count or 50
	local out = {}
	for i = math.max(1, #ring - n + 1), #ring do
		table.insert(out, ring[i])
	end
	return out
end

function TelemetryService.build(): string
	return BUILD
end

return TelemetryService
