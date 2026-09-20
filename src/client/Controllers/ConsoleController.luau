--!strict
-- Liga a interface do console de teste quando o servidor a publica. Se o console estiver
-- desligado, `CmdrClient` nunca aparece em ReplicatedStorage e este controlador não faz nada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConsoleController = {}

local WAIT_SECONDS = 10

function ConsoleController.init()
	task.spawn(function()
		local root = ReplicatedStorage:WaitForChild("CmdrClient", WAIT_SECONDS)
		if not root or not root:IsA("ModuleScript") then
			return
		end
		local Cmdr = require(root) :: any
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
		Cmdr:SetPlaceName("Quintal em Guarda")
		-- O jogo é 2D e o mouse já está livre; destravar de novo tiraria o cursor do lugar.
		Cmdr:SetActivationUnlocksMouse(false)
	end)
end

return ConsoleController
