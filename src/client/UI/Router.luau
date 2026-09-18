--!strict
-- Pilha de navegação entre telas de menu.
--
-- Regras do guia:
--  * apenas uma tela principal por vez;
--  * Configurações abre de qualquer origem e volta à mesma origem (por isso é `push`, não `go`);
--  * "Voltar ao menu" na galeria de referência não substitui esta pilha;
--  * ao voltar, a seleção da tela anterior é preservada (a tela recebe os mesmos parâmetros).
local Router = {}

export type Params = { [string]: any }
export type Screen = {
	show: (params: Params) -> (),
	hide: () -> (),
	-- Chamado quando a tela volta ao topo depois de uma camada acima fechar.
	resume: ((params: Params) -> ())?,
}

type Entry = { name: string, params: Params }

local screens: { [string]: Screen } = {}
local stack: { Entry } = {}
local listeners: { (name: string) -> () } = {}

local function activate(entry: Entry, resuming: boolean)
	local screen = screens[entry.name]
	assert(screen, `tela não registrada: {entry.name}`)
	if resuming and screen.resume then
		screen.resume(entry.params)
	else
		screen.show(entry.params)
	end
	for _, fn in ipairs(listeners) do
		task.spawn(fn, entry.name)
	end
end

local function deactivate(entry: Entry)
	local screen = screens[entry.name]
	if screen then
		screen.hide()
	end
end

function Router.register(name: string, screen: Screen)
	screens[name] = screen
end

function Router.onChange(fn: (name: string) -> ())
	table.insert(listeners, fn)
end

function Router.current(): string?
	local top = stack[#stack]
	return if top then top.name else nil
end

function Router.depth(): number
	return #stack
end

-- Substitui a tela atual (navegação principal: menu → mapas → salas).
function Router.go(name: string, params: Params?)
	local top = stack[#stack]
	if top and top.name == name then
		top.params = params or {}
		activate(top, false)
		return
	end
	if top then
		deactivate(top)
		table.remove(stack)
	end
	local entry: Entry = { name = name, params = params or {} }
	table.insert(stack, entry)
	activate(entry, false)
end

-- Empilha mantendo a origem viva na pilha (Configurações, detalhe de torre, convites).
function Router.push(name: string, params: Params?)
	local top = stack[#stack]
	if top then
		deactivate(top)
	end
	local entry: Entry = { name = name, params = params or {} }
	table.insert(stack, entry)
	activate(entry, false)
end

-- Volta para a origem exata, com os parâmetros que ela tinha.
function Router.back(): boolean
	if #stack <= 1 then
		return false
	end
	local top = table.remove(stack) :: Entry
	deactivate(top)
	activate(stack[#stack], true)
	return true
end

-- Volta até uma tela específica (usada ao sair de fluxos profundos, ex.: torre → coleção).
function Router.backTo(name: string): boolean
	local found = false
	for _, entry in ipairs(stack) do
		if entry.name == name then
			found = true
			break
		end
	end
	if not found then
		return false
	end
	while #stack > 1 and (stack[#stack] :: Entry).name ~= name do
		deactivate(table.remove(stack) :: Entry)
	end
	activate(stack[#stack], true)
	return true
end

-- Limpa a pilha e começa de novo (entrada da experiência, retorno de partida).
function Router.reset(name: string, params: Params?)
	for index = #stack, 1, -1 do
		deactivate(stack[index])
		stack[index] = nil
	end
	local entry: Entry = { name = name, params = params or {} }
	stack[1] = entry
	activate(entry, false)
end

-- Esconde a tela ativa sem desmontar a pilha (entrada em partida).
function Router.suspend()
	local top = stack[#stack]
	if top then
		deactivate(top)
	end
end

function Router.resume()
	local top = stack[#stack]
	if top then
		activate(top, true)
	end
end

function Router.params(): Params
	local top = stack[#stack]
	return if top then top.params else {}
end

return Router
