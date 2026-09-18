--!strict
-- Componente de referência. Integrar e validar em Studio.
-- A callback só emite intenção. A confirmação vem do CommandAdapter.
local TweenService = game:GetService("TweenService")
local ButtonFeedback = {}

function ButtonFeedback.bind(button: GuiButton, onActivate: () -> (), reducedMotion: () -> boolean)
 local scale = Instance.new("UIScale")
 scale.Name = "InteractionScale"
 scale.Scale = 1
 scale.Parent = button
 local focusStroke = Instance.new("UIStroke")
 focusStroke.Name = "FocusRing"
 focusStroke.Color = Color3.fromRGB(25, 40, 63)
 focusStroke.Thickness = 3
 focusStroke.Enabled = false
 focusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 focusStroke.Parent = button
 button.AutoButtonColor = false
 local enabled, pending, hover, focused, alive = true, false, false, false, true
 local tween: Tween? = nil
 local links: {RBXScriptConnection} = {}
 local generation = 0
 local function animate(value: number, duration: number)
  if tween then tween:Cancel() end
  if reducedMotion() then scale.Scale = 1; return end
  tween = TweenService:Create(scale, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value})
  tween:Play()
 end
 local function settle()
  if not alive then return end
  focusStroke.Enabled = focused
  animate(if enabled and not pending and (hover or focused) then 1.03 else 1, 0.10)
 end
 table.insert(links, button.MouseEnter:Connect(function() hover = true; settle() end))
 table.insert(links, button.MouseLeave:Connect(function() hover = false; settle() end))
 table.insert(links, button.SelectionGained:Connect(function() focused = true; settle() end))
 table.insert(links, button.SelectionLost:Connect(function() focused = false; settle() end))
 table.insert(links, button.Activated:Connect(function()
  if not alive or not enabled or pending then return end
  generation += 1
  local token = generation
  animate(0.97, 0.08)
  task.delay(0.08, function() if alive and generation == token then settle() end end)
  -- O dono do componente deve marcar pending sincronicamente para comandos remotos.
  onActivate()
 end))
 local controller = {}
 function controller.setState(nextEnabled: boolean, nextPending: boolean)
  enabled, pending = nextEnabled, nextPending
  button.Active = nextEnabled and not nextPending
  -- O rótulo/motivo visual pertence ao componente de apresentação.
  settle()
 end
 function controller.refreshMotion() settle() end
 function controller.destroy()
  if not alive then return end
  alive = false; generation += 1
  if tween then tween:Cancel() end
  for _, link in links do link:Disconnect() end
  scale:Destroy(); focusStroke:Destroy()
 end
 return controller
end
return ButtonFeedback
