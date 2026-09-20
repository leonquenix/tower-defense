--!strict
-- Ponto de entrada do cliente: ambiente 3D estável, estado, rede e montagem da interface.
--
-- Ordem: átomos e preferências primeiro, rede depois, interface por último — assim a primeira
-- tela já é desenhada com o que chegou do servidor, sem piscar conteúdo vazio.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- ambiente 3D estável atrás da aplicação 2D
local camera = workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(0, 500, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0)
end
-- mochila, vida e emotes não fazem sentido num jogo 2D de ScreenGui.
-- O menu do Roblox e o restante da CoreGui continuam intactos (o guia proíbe escondê-los).
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end)

-- aguarda a janela ter tamanho real antes de decidir o layout (celular x computador)
local deadline = os.clock() + 3
while (workspace.CurrentCamera == nil or workspace.CurrentCamera.ViewportSize.X < 100) and os.clock() < deadline do
	task.wait(0.05)
end

local Actions = require(script.Parent.State.Actions)
local Atoms = require(script.Parent.State.Atoms)
local Client = require(script.Parent.Net.Client)
local Commands = require(script.Parent.Net.Commands)
local App = require(script.Parent.UI.App)
local BoardPresenter = require(script.Parent.Controllers.BoardPresenter)
local MatchController = require(script.Parent.Controllers.MatchController)
local SettingsController = require(script.Parent.Controllers.SettingsController)
local ConsoleController = require(script.Parent.Controllers.ConsoleController)

MatchController.init()
BoardPresenter.init()
ConsoleController.init()

-- Lobby e convites entram direto no estado; a interface só lê.
Client.onLobby(function(kind: string, payload: any)
	if kind == "lobby" then
		Actions.setLobby(payload)
		local profile = payload.profile
		if profile and (profile.status == "ready" or profile.status == "volatile") then
			if profile.settings then
				SettingsController.apply(profile.settings)
			end
			if profile.loadout then
				Atoms.loadout(table.clone(profile.loadout))
			end
			-- perfil pronto e fora de partida: sai da tela de entrada
			if Atoms.route() == "boot" and not payload.inMatch and not Atoms.inMatch() then
				Actions.navigate("menu")
			end
		end
	elseif kind == "invite" then
		Actions.addInvite({
			inviteId = tostring(payload.inviteId),
			partyId = tostring(payload.partyId),
			fromUserId = payload.fromUserId,
			fromName = tostring(payload.fromName),
			mapId = payload.mapId,
			difficulty = payload.difficulty,
			expiresAt = os.clock() + (payload.expiresIn or 30),
			state = "pending",
		})
	end
end)

-- Recompensas registradas mas não creditadas são reconciliadas ao voltar para o menu.
MatchController.on("left", function()
	Commands.send("result:claim", "ClaimPending", {}, nil)
end)

App.init({
	playerGui = playerGui,
	localUserId = player.UserId,
	onBoardArea = BoardPresenter.attach,
})

-- Trocar o idioma remonta a árvore inteira (texto é escrito na construção).
SettingsController.onLocaleChanged(function()
	App.mount()
end)
