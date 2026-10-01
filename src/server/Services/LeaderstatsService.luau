--!strict
-- Nível e vitórias na lista de jogadores do Roblox (leaderstats). É a única vitrine social que
-- um jogo 2D tem sem lobby 3D: quem entra no servidor vê de cara quem já avançou.
--
-- Só espelha o perfil; nunca é lido de volta.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Localization = require(Shared.Config.Localization)
local Progression = require(Shared.Rules.Progression)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderstatsService = {}

local function intValue(folder: Instance, name: string): IntValue
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local created = Instance.new("IntValue")
	created.Name = name
	created.Parent = folder
	return created
end

local function ensure(player: Player): (IntValue, IntValue)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end
	local parent = folder :: Instance
	return intValue(parent, Localization.get("leaderstats.level")),
		intValue(parent, Localization.get("leaderstats.wins"))
end

function LeaderstatsService.refresh(player: Player)
	if player.Parent ~= Players then
		return
	end
	local profile = PlayerDataService.get(player)
	local level, wins = ensure(player)
	if profile then
		level.Value = Progression.levelOf(profile.xp)
		wins.Value = profile.lifetimeStats.wins
	end
end

function LeaderstatsService.init()
	-- toda mudança de perfil passa por aqui (mutate notifica), então nível e vitórias andam juntos
	PlayerDataService.onSessionChanged(function(player: Player)
		LeaderstatsService.refresh(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		LeaderstatsService.refresh(player)
	end
end

return LeaderstatsService
