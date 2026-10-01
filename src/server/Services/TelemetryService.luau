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

-- Funil de primeira sessão do Roblox (painel pronto no Creator Hub). Os passos são fixos e
-- crescentes; cada jogador registra cada passo uma vez (o perfil guarda o maior já enviado).
TelemetryService.ONBOARDING = {
	joined = 1,
	firstMatch = 2,
	firstTower = 3,
	firstWave = 4,
	level1Won = 5,
	level2Won = 6,
	level3Won = 7,
	accountLevel3 = 8,
}

function TelemetryService.onboarding(player: Player, step: number, stepName: string)
	TelemetryService.log("onboarding", { userId = player.UserId, step = step, stepName = stepName })
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
		end)
	end)
end

-- Movimento de moeda ou ficha (fonte = ganhou, sumidouro = gastou). Vira o painel de economia.
function TelemetryService.economy(
	player: Player,
	source: boolean,
	currency: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string?
)
	TelemetryService.log("economy", {
		userId = player.UserId,
		flow = if source then "source" else "sink",
		currency = currency,
		amount = amount,
		balance = balance,
		transaction = transaction,
		sku = sku,
	})
	if RunService:IsStudio() or amount <= 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogEconomyEvent(
				player,
				if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
				currency,
				amount,
				balance,
				transaction,
				sku
			)
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
