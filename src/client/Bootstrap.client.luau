--!strict
-- Ponto de entrada do cliente: cria o ScreenGui da aplicação em PlayerGui, câmera Scriptable e fundo opaco.
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
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end)

local existing = playerGui:FindFirstChild("QuintalApp")
if existing then
	existing:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "QuintalApp"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromHex("14202F")
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = gui

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
ReplicatedStorage:WaitForChild(Protocol.REMOTE_FOLDER, 60)

-- aguarda a janela ter tamanho real antes de decidir o layout (celular x computador)
local deadline = os.clock() + 3
while gui.AbsoluteSize.X < 100 and os.clock() < deadline do
	task.wait(0.05)
end

local MatchController = require(script.Parent.Controllers.MatchController)
local ScreenController = require(script.Parent.Controllers.ScreenController)

MatchController.init()
ScreenController.init(gui)
