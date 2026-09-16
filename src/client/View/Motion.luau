--!strict
-- Transições de interface (tempo real). Respeitam o modo de movimento reduzido: sem deslocamento nem pulsação.
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local Motion = {}

Motion.FAST = 0.12
Motion.NORMAL = 0.2
Motion.SLOW = 0.32

local function info(duration: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
end

local function basePosition(frame: GuiObject): UDim2
	local stored = frame:GetAttribute("motionBase")
	if typeof(stored) == "UDim2" then
		return stored
	end
	frame:SetAttribute("motionBase", frame.Position)
	return frame.Position
end

-- Atualiza a posição de repouso quando o layout muda
function Motion.setBase(frame: GuiObject, position: UDim2)
	frame:SetAttribute("motionBase", position)
	frame.Position = position
end

function Motion.tween(instance: Instance, props: { [string]: any }, duration: number?, style: Enum.EasingStyle?): Tween?
	if Ui.isReducedMotion() then
		for k, v in pairs(props) do
			(instance :: any)[k] = v
		end
		return nil
	end
	local tween = TweenService:Create(instance, info(duration or Motion.NORMAL, style), props)
	tween:Play()
	return tween
end

-- Entra deslizando a partir de um deslocamento em pixels até a posição de repouso.
function Motion.slideIn(frame: GuiObject, dx: number, dy: number, duration: number?)
	local base = basePosition(frame)
	frame.Visible = true
	if Ui.isReducedMotion() then
		frame.Position = base
		return
	end
	frame.Position = base + UDim2.fromOffset(dx, dy)
	TweenService:Create(frame, info(duration or Motion.NORMAL, Enum.EasingStyle.Back), { Position = base }):Play()
end

-- Sai deslizando e oculta ao terminar (se nada reexibiu o painel nesse meio-tempo).
function Motion.slideOut(frame: GuiObject, dx: number, dy: number, duration: number?)
	local base = basePosition(frame)
	if Ui.isReducedMotion() or not frame.Visible then
		frame.Visible = false
		frame.Position = base
		return
	end
	local token = ((frame:GetAttribute("motionToken") :: any) or 0) + 1
	frame:SetAttribute("motionToken", token)
	local tween = TweenService:Create(
		frame,
		info(duration or Motion.FAST, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = base + UDim2.fromOffset(dx, dy) }
	)
	tween:Play()
	tween.Completed:Once(function()
		if frame:GetAttribute("motionToken") == token then
			frame.Visible = false
			frame.Position = base
		end
	end)
end

-- Aparece com leve crescimento (usa UIScale filho).
function Motion.popIn(frame: GuiObject, duration: number?)
	frame.Visible = true
	if Ui.isReducedMotion() then
		return
	end
	local existing = frame:FindFirstChildOfClass("UIScale")
	local s: UIScale = if existing then existing else Instance.new("UIScale")
	if not existing then
		s.Parent = frame
	end
	s.Scale = 0.94
	TweenService:Create(s, info(duration or Motion.NORMAL, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Esmaece um CanvasGroup para dentro/fora.
function Motion.fadeGroup(group: CanvasGroup, visible: boolean, duration: number?, onHidden: (() -> ())?)
	if visible then
		group.Visible = true
		if Ui.isReducedMotion() then
			group.GroupTransparency = 0
			return
		end
		group.GroupTransparency = 1
		TweenService:Create(group, info(duration or Motion.NORMAL), { GroupTransparency = 0 }):Play()
	else
		if Ui.isReducedMotion() then
			group.Visible = false
			if onHidden then
				onHidden()
			end
			return
		end
		local tween = TweenService:Create(group, info(duration or Motion.FAST), { GroupTransparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			if group.GroupTransparency >= 0.99 then
				group.Visible = false
				if onHidden then
					onHidden()
				end
			end
		end)
	end
end

-- Pulso curto de destaque (escala 1 -> 1.04 -> 1)
function Motion.pulse(frame: GuiObject)
	if Ui.isReducedMotion() then
		return
	end
	local existing = frame:FindFirstChildOfClass("UIScale")
	local s: UIScale = if existing then existing else Instance.new("UIScale")
	if not existing then
		s.Parent = frame
	end
	local up = TweenService:Create(s, info(0.09), { Scale = 1.05 })
	up:Play()
	up.Completed:Once(function()
		TweenService:Create(s, info(0.14), { Scale = 1 }):Play()
	end)
end

-- Interpola um número exibido (para contadores fluidos)
function Motion.lerpNumber(current: number, target: number, alpha: number): number
	if Ui.isReducedMotion() or math.abs(target - current) < 1 then
		return target
	end
	return current + (target - current) * alpha
end

return Motion
