--!strict
-- Ponto de entrada do cliente: prepara o ambiente 3D estável e monta as camadas de interface.
-- As ScreenGuis (mundo, HUD, menu, modal e toast) são criadas por UI/Layers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- ambiente 3D estável atrás da aplicação
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

-- limpa uma montagem anterior (recarregar o script com o Rojo conectado)
local legacy = playerGui:FindFirstChild("QuintalApp")
if legacy then
	legacy:Destroy()
end

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
ReplicatedStorage:WaitForChild(Protocol.REMOTE_FOLDER, 60)

-- aguarda a janela ter tamanho real antes de decidir o layout (celular x computador)
local deadline = os.clock() + 3
while (workspace.CurrentCamera == nil or workspace.CurrentCamera.ViewportSize.X < 100) and os.clock() < deadline do
	task.wait(0.05)
end

local MatchController = require(script.Parent.Controllers.MatchController)
local ScreenController = require(script.Parent.Controllers.ScreenController)

MatchController.init()
ScreenController.init(playerGui)
