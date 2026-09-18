--!strict
-- Gerenciador de foco e teclado da interface.
--
-- Contrato do guia:
--  * Tab percorre as ações visíveis na ordem de leitura da camada ativa; Shift+Tab volta.
--    Em alguns clientes o Tab é reservado pela CoreGui e chega marcado como processado: nesse
--    caso ele é ignorado (o guia manda não disputar a tecla) e as setas cumprem o mesmo papel.
--  * Setas movem o foco dentro da camada ativa depois que já existe um item focado.
--  * Clicar ou tocar num botão também leva o foco de teclado até ele, para que a navegação
--    continue de onde o jogador estava.
--  * Enter/Espaço ativa o item focado (sem disparar nenhuma outra confirmação redundante).
--  * Escape cancela a camada local apenas quando o CoreGui não consumiu a tecla.
--  * Fechar um modal devolve o foco ao botão que o abriu, desde que ele ainda exista.
--  * Nenhum atalho dispara enquanto houver um TextBox em foco.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Focus = {}

export type Entry = {
	button: GuiButton,
	activate: () -> (),
	isAvailable: () -> boolean,
	scope: string,
	order: number,
}

local entries: { Entry } = {}
local scopeStack: { string } = { "root" }
local returnTargets: { [string]: GuiButton } = {}
local escapeHandlers: { [string]: () -> () } = {}
local focused: GuiButton? = nil
local sequence = 0

local function activeScope(): string
	return scopeStack[#scopeStack]
end

local function isTyping(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

-- Ordem de leitura: de cima para baixo, da esquerda para a direita, dentro da camada ativa.
local function orderedEntries(): { Entry }
	local scope = activeScope()
	local list: { Entry } = {}
	for _, entry in ipairs(entries) do
		if entry.scope == scope and entry.button.Parent ~= nil and entry.button.Visible and entry.isAvailable() then
			local visible = true
			local node: Instance? = entry.button.Parent
			while node and node:IsA("GuiObject") do
				if not (node :: GuiObject).Visible then
					visible = false
					break
				end
				node = node.Parent
			end
			if visible then
				table.insert(list, entry)
			end
		end
	end
	table.sort(list, function(a, b)
		local pa, pb = a.button.AbsolutePosition, b.button.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 8 then
			return pa.Y < pb.Y
		end
		if math.abs(pa.X - pb.X) > 0.5 then
			return pa.X < pb.X
		end
		return a.order < b.order
	end)
	return list
end

local function setFocused(button: GuiButton?)
	focused = button
	-- SelectedObject alimenta SelectionGained/SelectionLost, que os componentes usam para o contorno.
	pcall(function()
		GuiService.SelectedObject = button
	end)
end

function Focus.current(): GuiButton?
	return focused
end

-- Registra um botão navegável. Retorna a função de remoção (chamar no cleanup do componente).
function Focus.register(button: GuiButton, activate: () -> (), isAvailable: (() -> boolean)?, scope: string?): () -> ()
	sequence += 1
	local entry: Entry = {
		button = button,
		activate = activate,
		isAvailable = isAvailable or function()
			return true
		end,
		scope = scope or activeScope(),
		order = sequence,
	}
	table.insert(entries, entry)
	return function()
		local index = table.find(entries, entry)
		if index then
			table.remove(entries, index)
		end
		if focused == button then
			setFocused(nil)
		end
	end
end

function Focus.move(delta: number)
	local list = orderedEntries()
	if #list == 0 then
		setFocused(nil)
		return
	end
	local index = 0
	for i, entry in ipairs(list) do
		if entry.button == focused then
			index = i
			break
		end
	end
	local nextIndex = if index == 0 then (if delta > 0 then 1 else #list) else ((index - 1 + delta) % #list) + 1
	setFocused(list[nextIndex].button)
end

function Focus.activateFocused()
	local button = focused
	if not button then
		return
	end
	for _, entry in ipairs(entries) do
		if entry.button == button and entry.isAvailable() then
			entry.activate()
			return
		end
	end
end

function Focus.set(button: GuiButton?)
	setFocused(button)
end

-- Abre uma camada (modal, folha, popover). `opener` recebe o foco de volta ao fechar.
function Focus.pushScope(scope: string, opener: GuiButton?, onEscape: (() -> ())?)
	table.insert(scopeStack, scope)
	if opener then
		returnTargets[scope] = opener
	end
	if onEscape then
		escapeHandlers[scope] = onEscape
	end
end

-- Fecha a camada e devolve o foco ao botão de origem, se ele ainda existir na árvore.
function Focus.popScope(scope: string)
	for i = #scopeStack, 2, -1 do
		if scopeStack[i] == scope then
			table.remove(scopeStack, i)
			break
		end
	end
	escapeHandlers[scope] = nil
	local opener = returnTargets[scope]
	returnTargets[scope] = nil
	if opener and opener.Parent and opener.Visible then
		setFocused(opener)
	else
		setFocused(nil)
	end
end

function Focus.scope(): string
	return activeScope()
end

-- Handler de Escape da camada ativa (nil quando é a raiz: quem trata é a tela).
function Focus.escape(): boolean
	local handler = escapeHandlers[activeScope()]
	if handler then
		handler()
		return true
	end
	return false
end

function Focus.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or isTyping() then
			return -- CoreGui/menu do Roblox tem prioridade; digitação nunca dispara atalho
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Tab then
			Focus.move(
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
						or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
					then -1
					else 1
			)
		elseif focused ~= nil and (key == Enum.KeyCode.Down or key == Enum.KeyCode.Right) then
			Focus.move(1)
		elseif focused ~= nil and (key == Enum.KeyCode.Up or key == Enum.KeyCode.Left) then
			Focus.move(-1)
		elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.Space then
			if focused then
				Focus.activateFocused()
			end
		elseif key == Enum.KeyCode.Escape then
			Focus.escape()
		end
	end)
end

return Focus
