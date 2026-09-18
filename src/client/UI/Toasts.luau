--!strict
-- Fila de avisos curtos (prancha 31/45).
--
-- Regras do guia:
--  * sucesso some em 2,5 s; informação em 4 s; erro que exige decisão fica inline, não aqui;
--  * no máximo três na tela, com deduplicação por tipo/entidade dentro de 1 s;
--  * nunca cobre os quatro slots nem a confirmação: a fila vive no topo, abaixo da faixa do HUD;
--  * toast não recebe foco e não é botão.
local Localization = require(game:GetService("ReplicatedStorage").Shared.Config.Localization)
local Theme = require(script.Parent.Parent.View.Theme)
local Accessibility = require(script.Parent.Accessibility)
local Anim = require(script.Parent.Anim)
local Components = require(script.Parent.Components)

local Toasts = {}

export type Kind = "success" | "info" | "error"

local HOLD: { [string]: number } = { success = 2.5, info = 4, error = 4 }
local MAX_VISIBLE = 3
local DEDUPE_WINDOW = 1

type Entry = { frame: CanvasGroup, key: string, expiresAt: number }

local host: Frame? = nil
local active: { Entry } = {}
local lastShown: { [string]: number } = {}
local topOffset = 76

local function layout()
	for index, entry in ipairs(active) do
		local target = UDim2.new(0.5, 0, 0, topOffset + (index - 1) * 48)
		if Accessibility.reducedMotion() then
			entry.frame.Position = target
		else
			Anim.play(entry.frame, "toast", { Position = target })
		end
	end
end

local function remove(entry: Entry)
	local index = table.find(active, entry)
	if index then
		table.remove(active, index)
	end
	local frame = entry.frame
	if not frame.Parent then
		return
	end
	local tween = Anim.fade(frame, "GroupTransparency", 1, "panel_exit")
	local function destroy()
		Anim.cancelAll(frame)
		frame:Destroy()
		layout()
	end
	if tween then
		tween.Completed:Once(destroy)
	else
		destroy()
	end
end

-- A faixa superior do HUD muda de altura entre computador e celular: a fila desce abaixo dela.
function Toasts.setTopOffset(offset: number)
	topOffset = offset
	layout()
end

function Toasts.init(parent: Frame)
	host = parent
end

-- `key` identifica tipo/entidade para a deduplicação (ex.: "error:OCCUPIED", "circuit:17").
function Toasts.show(text: string, kind: Kind?, key: string?)
	local parent = host
	if not parent then
		return
	end
	local resolvedKind: Kind = kind or "info"
	local dedupeKey = key or (resolvedKind .. ":" .. text)
	local now = os.clock()
	if lastShown[dedupeKey] and now - lastShown[dedupeKey] < DEDUPE_WINDOW then
		return
	end
	lastShown[dedupeKey] = now
	while #active >= MAX_VISIBLE do
		remove(active[1])
	end

	local frame = Instance.new("CanvasGroup")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, topOffset + #active * 48)
	frame.Size = UDim2.fromOffset(10, 40)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundColor3 = if resolvedKind == "error" then Theme.colors.dangerSoft else Theme.colors.surface
	frame.BorderSizePixel = 0
	frame.Active = false -- não intercepta toque: o mundo e os painéis continuam acessíveis
	frame.Parent = parent
	Components.corner(frame, Theme.sizes.pillCorner)
	Components.stroke(frame, if resolvedKind == "error" then Theme.colors.danger else Theme.colors.ink)
	Components.padding(frame, 14, 8)
	local row = Components.frame(frame, "Row", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Active = false,
	})
	Components.list(row, Enum.FillDirection.Horizontal, 8)
	local iconKey = if resolvedKind == "error"
		then "ui_error"
		elseif resolvedKind == "success" then "ui_check"
		else "ui_wave"
	local handle = Components.icon(row, iconKey, 18, { LayoutOrder = 1 })
	if handle then
		handle:setColor(if resolvedKind == "error" then Theme.colors.danger else Theme.colors.ink)
	end
	Components.label(row, "Text", text, {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		TextColor3 = if resolvedKind == "error" then Theme.colors.danger else Theme.colors.ink,
		Font = Theme.fonts.bodyMedium,
		LayoutOrder = 2,
	})

	local entry: Entry = { frame = frame, key = dedupeKey, expiresAt = now + HOLD[resolvedKind] }
	table.insert(active, entry)
	if Accessibility.reducedMotion() then
		frame.GroupTransparency = 0
	else
		frame.GroupTransparency = 1
		frame.Position = UDim2.new(0.5, 0, 0, topOffset + (#active - 1) * 48 - 8)
		Anim.play(frame, "toast", {
			GroupTransparency = 0,
			Position = UDim2.new(0.5, 0, 0, topOffset + (#active - 1) * 48),
		})
	end
	task.delay(HOLD[resolvedKind], function()
		if table.find(active, entry) then
			remove(entry)
		end
	end)
end

function Toasts.success(text: string, key: string?)
	Toasts.show(text, "success", key)
end

function Toasts.info(text: string, key: string?)
	Toasts.show(text, "info", key)
end

-- Erro de transação antiga/contextual. Erros que exigem decisão ficam inline na tela de origem.
function Toasts.error(code: string?)
	local resolved = code or "INVALID_STATE"
	local key = "error." .. resolved
	local text = if Localization.has(key) then Localization.get(key) else Localization.get("error.UNKNOWN")
	Toasts.show(text, "error", "error:" .. resolved)
end

function Toasts.clear()
	for index = #active, 1, -1 do
		local entry = active[index]
		table.remove(active, index)
		Anim.cancelAll(entry.frame)
		entry.frame:Destroy()
	end
	table.clear(lastShown)
end

return Toasts
