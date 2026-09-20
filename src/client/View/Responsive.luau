--!strict
-- Layout responsivo: modo (computador x compacto) e escala uniforme derivados do tamanho real da janela.
-- Referência de desenho: 1280x720 (computador) e 750x360 (celular em paisagem).
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Responsive = {}

export type Mode = "desktop" | "compact"
export type State = { mode: Mode, scale: number, viewport: Vector2 }

Responsive.REFERENCE_DESKTOP = Vector2.new(1280, 720)
Responsive.REFERENCE_COMPACT = Vector2.new(760, 340)
Responsive.MIN_DESKTOP = Vector2.new(1000, 540)

local current: State = { mode = "desktop", scale = 1, viewport = Vector2.new(1280, 720) }
local listeners: { (State, boolean) -> () } = {}
local debounceToken = 0

function Responsive.viewportSize(): Vector2
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Responsive.REFERENCE_DESKTOP
	if size.X <= 1 or size.Y <= 1 then
		size = Responsive.REFERENCE_DESKTOP
	end
	local inset = GuiService:GetGuiInset()
	return Vector2.new(size.X, math.max(size.Y - inset.Y, 200))
end

function Responsive.isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Responsive.computeMode(viewport: Vector2): Mode
	local compact: Mode = "compact"
	local desktop: Mode = "desktop"
	if Responsive.isTouchOnly() and viewport.Y < 700 then
		return compact
	end
	if viewport.X < Responsive.MIN_DESKTOP.X or viewport.Y < Responsive.MIN_DESKTOP.Y then
		return compact
	end
	return desktop
end

-- Escala nunca fica abaixo de 1: telas pequenas trocam de layout em vez de encolher botões.
function Responsive.computeScale(viewport: Vector2, mode: Mode): number
	if mode == "desktop" then
		local ref = Responsive.REFERENCE_DESKTOP
		return math.clamp(math.min(viewport.X / ref.X, viewport.Y / ref.Y), 1, 1.8)
	end
	local ref = Responsive.REFERENCE_COMPACT
	return math.clamp(math.min(viewport.X / ref.X, viewport.Y / ref.Y), 1, 1.35)
end

-- Escala das telas de menu (menu, campanha, loja, resultado…). Elas são escritas na régua de
-- 1280x720 e não têm layout compacto próprio: numa tela pequena é melhor encolher a tela inteira,
-- para caber, do que deixar metade dos botões fora da borda. O HUD **não** usa esta escala — ele
-- tem métricas compactas próprias, para o alvo de toque continuar do tamanho de um dedo.
function Responsive.menuScale(viewport: Vector2): number
	local ref = Responsive.REFERENCE_DESKTOP
	return math.clamp(math.min(viewport.X / ref.X, viewport.Y / ref.Y), 0.5, 1.8)
end

function Responsive.get(): State
	return current
end

function Responsive.isCompact(): boolean
	return current.mode == "compact"
end

-- Recalcula; retorna se o modo mudou.
function Responsive.refresh(): boolean
	local viewport = Responsive.viewportSize()
	local mode: Mode = Responsive.computeMode(viewport)
	local scale = Responsive.computeScale(viewport, mode)
	local modeChanged = mode ~= current.mode
	local next: State = { mode = mode :: Mode, scale = scale, viewport = viewport }
	current = next
	return modeChanged
end

function Responsive.onChange(fn: (State, boolean) -> ())
	table.insert(listeners, fn)
end

local function notify(modeChanged: boolean)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, current, modeChanged)
	end
end

function Responsive.init()
	Responsive.refresh()
	local function schedule()
		debounceToken += 1
		local token = debounceToken
		task.delay(0.15, function()
			if token ~= debounceToken then
				return
			end
			local before = current
			local modeChanged = Responsive.refresh()
			if modeChanged or math.abs(before.scale - current.scale) > 0.001 or before.viewport ~= current.viewport then
				notify(modeChanged)
			end
		end)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(schedule)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(schedule)
		end
		schedule()
	end)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(schedule)
end

return Responsive
