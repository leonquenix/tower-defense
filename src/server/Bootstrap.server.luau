--!strict
-- Ponto de entrada do servidor. Sem avatares: o jogo é uma aplicação 2D em ScreenGui.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TelemetryService = require(script.Parent.Services.TelemetryService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local RewardService = require(script.Parent.Services.RewardService)
local ShopService = require(script.Parent.Services.ShopService)
local MatchService = require(script.Parent.Services.MatchService)
local PartyService = require(script.Parent.Services.PartyService)
local CommandService = require(script.Parent.Services.CommandService)
local ConsoleService = require(script.Parent.Services.ConsoleService)

Players.CharacterAutoLoads = false

-- ambiente 3D vazio e estável atrás da aplicação
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "SpawnLocation") then
		child:Destroy()
	end
end

local Lighting = game:GetService("Lighting")
Lighting.Brightness = 0
Lighting.ClockTime = 0
Lighting.GlobalShadows = false
Lighting.Ambient = Color3.fromHex("19283F")
Lighting.OutdoorAmbient = Color3.fromHex("19283F")

PlayerDataService.init()
RewardService.init()
ShopService.init()
PartyService.init()
MatchService.init({
	onPlayerFreed = PartyService.onPlayerFreed,
	onRematch = PartyService.onRematch,
})
CommandService.init()
ConsoleService.init()

local function onPlayerAdded(player: Player)
	PlayerDataService.onPlayerAdded(player)
	MatchService.onPlayerAdded(player)
	PartyService.onPlayerAdded(player)
	TelemetryService.funnel(player, "onboarding", 1, "joined")
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	MatchService.onPlayerRemoving(player)
	PartyService.onPlayerRemoving(player)
	PlayerDataService.onPlayerRemoving(player)
end)

TelemetryService.log(
	"server_start",
	{ build = TelemetryService.build(), studio = game:GetService("RunService"):IsStudio() }
)
