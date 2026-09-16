--!strict
-- Entrada do tabuleiro: toque/clique em célula, seleção, teclas 1-4/Esc/U, arrastar com dois dedos e zoom.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local BoardTransform = require(script.Parent.Parent.View.BoardTransform)
local Responsive = require(script.Parent.Parent.View.Responsive)

local InputController = {}

export type Callbacks = {
	onTap: (screen: Vector2) -> (),
	onHover: (screen: Vector2?) -> (),
	onPickSlot: (slot: number) -> (),
	onCancel: () -> (),
	onUpgradeKey: () -> (),
}

local transform: BoardTransform.BoardTransform
local callbacks: Callbacks
local enabled = false
local touches: { [InputObject]: Vector2 } = {}
local touchStart: { [InputObject]: { pos: Vector2, at: number } } = {}
local pinchStartDistance: number? = nil
local pinchStartZoom = 1
local lastPanCenter: Vector2? = nil
local mousePanning = false
local lastMousePos: Vector2? = nil
local connections: { RBXScriptConnection } = {}
local TAP_MOVE_TOLERANCE = 12
local TAP_TIME = 0.5

local function touchCount(): number
	local n = 0
	for _ in pairs(touches) do
		n += 1
	end
	return n
end

local function twoTouches(): (Vector2?, Vector2?)
	local a: Vector2? = nil
	local b: Vector2? = nil
	for _, pos in pairs(touches) do
		if not a then
			a = pos
		elseif not b then
			b = pos
		end
	end
	return a, b
end

local function screenPosition(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if not enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		local pos = screenPosition(input)
		touches[input] = pos
		touchStart[input] = { pos = pos, at = os.clock() }
		if touchCount() == 2 then
			local a, b = twoTouches()
			if a and b then
				pinchStartDistance = (a - b).Magnitude
				pinchStartZoom = transform.zoom
				lastPanCenter = (a + b) / 2
			end
		end
		return
	end
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local pos = screenPosition(input)
		touchStart[input] = { pos = pos, at = os.clock() }
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3
	then
		mousePanning = true
		lastMousePos = screenPosition(input)
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		if key == Enum.KeyCode.One then
			callbacks.onPickSlot(1)
		elseif key == Enum.KeyCode.Two then
			callbacks.onPickSlot(2)
		elseif key == Enum.KeyCode.Three then
			callbacks.onPickSlot(3)
		elseif key == Enum.KeyCode.Four then
			callbacks.onPickSlot(4)
		elseif key == Enum.KeyCode.Escape then
			callbacks.onCancel()
		elseif key == Enum.KeyCode.U then
			callbacks.onUpgradeKey()
		end
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if not enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		if touches[input] then
			touches[input] = screenPosition(input)
			if touchCount() == 2 then
				local a, b = twoTouches()
				if a and b and pinchStartDistance and pinchStartDistance > 0 then
					local center = (a + b) / 2
					local distance = (a - b).Magnitude
					transform:setZoom(pinchStartZoom * (distance / pinchStartDistance), center, false)
					if lastPanCenter then
						transform:pan(center - lastPanCenter)
					end
					lastPanCenter = center
				end
			end
		end
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local pos = screenPosition(input)
		if mousePanning and lastMousePos then
			transform:pan(pos - lastMousePos)
			lastMousePos = pos
		elseif not processed then
			callbacks.onHover(pos)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		local pos = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
		if transform:isInsideWindow(pos) then
			local factor = if input.Position.Z > 0 then 1.15 else 1 / 1.15
			transform:setZoom(transform.zoom * factor, pos, false)
		end
	end
end

local function onInputEnded(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.Touch then
		local start = touchStart[input]
		local wasSingle = touchCount() == 1
		touches[input] = nil
		touchStart[input] = nil
		if touchCount() < 2 then
			pinchStartDistance = nil
			lastPanCenter = nil
		end
		if enabled and start and wasSingle and not processed then
			local pos = screenPosition(input)
			if (pos - start.pos).Magnitude <= TAP_MOVE_TOLERANCE and os.clock() - start.at <= TAP_TIME then
				callbacks.onTap(pos)
			end
		end
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local start = touchStart[input]
		touchStart[input] = nil
		if enabled and start and not processed then
			local pos = screenPosition(input)
			if (pos - start.pos).Magnitude <= TAP_MOVE_TOLERANCE then
				callbacks.onTap(pos)
			end
		end
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3
	then
		mousePanning = false
		lastMousePos = nil
	end
end

function InputController.init(boardTransform: BoardTransform.BoardTransform, cb: Callbacks)
	transform = boardTransform
	callbacks = cb
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
end

function InputController.setEnabled(value: boolean)
	enabled = value
	if not value then
		touches = {}
		touchStart = {}
		mousePanning = false
	end
end

function InputController.isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function InputController.isMobileLayout(): boolean
	return Responsive.isCompact()
end

function InputController.isPortrait(): boolean
	local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	return size.Y > size.X
end

function InputController.guiInset(): Vector2
	local inset = GuiService:GetGuiInset()
	return inset
end

return InputController
