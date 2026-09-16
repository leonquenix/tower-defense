--!strict
-- Ponto de entrada do servidor. Sem avatares: o jogo é uma aplicação 2D em ScreenGui.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TelemetryService = require(script.Parent.Services.TelemetryService)
local ProfileService = require(script.Parent.Services.ProfileService)
local RewardService = require(script.Parent.Services.RewardService)
local ShopService = require(script.Parent.Services.ShopService)
local MatchService = require(script.Parent.Services.MatchService)
local PartyService = require(script.Parent.Services.PartyService)
local CommandService = require(script.Parent.Services.CommandService)

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

local folder = ReplicatedStorage:FindFirstChild(Protocol.REMOTE_FOLDER) :: Folder?
if not folder then
	local created = Instance.new("Folder")
	created.Name = Protocol.REMOTE_FOLDER
	created.Parent = ReplicatedStorage
	folder = created
end
local remoteFolder = folder :: Folder

local function ensureRemote(name: string, className: string): Instance
	local existing = remoteFolder:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local commandRemote = ensureRemote(Protocol.COMMAND_REMOTE, "RemoteFunction") :: RemoteFunction
local stateRemote = ensureRemote(Protocol.STATE_REMOTE, "RemoteEvent") :: RemoteEvent
local lobbyRemote = ensureRemote(Protocol.LOBBY_REMOTE, "RemoteEvent") :: RemoteEvent

ProfileService.init()
RewardService.init()
ShopService.init()
PartyService.init(lobbyRemote)
MatchService.init(stateRemote, {
	onPlayerFreed = PartyService.onPlayerFreed,
	onRematch = PartyService.onRematch,
})
CommandService.init(commandRemote)

local function onPlayerAdded(player: Player)
	ProfileService.onPlayerAdded(player)
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
	ProfileService.onPlayerRemoving(player)
end)

TelemetryService.log(
	"server_start",
	{ build = TelemetryService.build(), studio = game:GetService("RunService"):IsStudio() }
)
