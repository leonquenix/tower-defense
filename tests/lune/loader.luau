--!nocheck
-- Carregador Roblox-like para Lune: expõe `script`, `require(instance)` e uma árvore virtual
-- ReplicatedStorage.Shared -> src/shared, ServerScriptService.Server -> src/server,
-- StarterPlayer.StarterPlayerScripts.Client -> src/client.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Loader = {}

local rootDir = nil
local moduleCache = {}

local Node = {}
Node.__index = function(self, key)
	local raw = rawget(Node, key)
	if raw ~= nil then
		return raw
	end
	local child = rawget(self, "_children")[key]
	if child == nil then
		error(string.format("%s is not a valid member of %s", tostring(key), rawget(self, "_fullName")), 2)
	end
	return child
end

function Node.new(name, parent, kind, filePath)
	local self = setmetatable({}, Node)
	rawset(self, "Name", name)
	rawset(self, "Parent", parent)
	rawset(self, "ClassName", kind)
	rawset(self, "_file", filePath)
	rawset(self, "_children", {})
	rawset(self, "_fullName", if parent then parent:GetFullName() .. "." .. name else name)
	return self
end

function Node:GetFullName()
	return rawget(self, "_fullName")
end

function Node:FindFirstChild(name)
	return rawget(self, "_children")[name]
end

function Node:WaitForChild(name)
	local c = rawget(self, "_children")[name]
	if c == nil then
		error("WaitForChild: " .. tostring(name) .. " não existe em " .. self:GetFullName())
	end
	return c
end

function Node:GetChildren()
	local list = {}
	for _, c in pairs(rawget(self, "_children")) do
		table.insert(list, c)
	end
	table.sort(list, function(a, b)
		return rawget(a, "Name") < rawget(b, "Name")
	end)
	return list
end

function Node:IsA(className)
	return rawget(self, "ClassName") == className
end

local function addChild(parent, child)
	rawget(parent, "_children")[rawget(child, "Name")] = child
end

-- Pacotes do Wally: cada pasta em _Index tem default.project.json apontando para src/.
-- O Rojo monta esse src como o próprio módulo; aqui fazemos o mesmo para que
-- require(ReplicatedStorage.Packages.Charm) funcione igual dentro e fora do Studio.
local function projectPathOf(dirPath)
	local manifest = dirPath .. "/default.project.json"
	if not fs.isFile(manifest) then
		return nil
	end
	local source = fs.readFile(manifest)
	local sub = source:match('"%$path"%s*:%s*"([^"]+)"')
	if sub and fs.isDir(dirPath .. "/" .. sub) then
		return dirPath .. "/" .. sub
	end
	return nil
end

local function scriptKindOf(name)
	if name:match("%.server$") then
		return name:gsub("%.server$", ""), "Script"
	elseif name:match("%.client$") then
		return name:gsub("%.client$", ""), "LocalScript"
	end
	return name, "ModuleScript"
end

local function mountDir(dirPath, parentNode)
	for _, entry in ipairs(fs.readDir(dirPath)) do
		local full = dirPath .. "/" .. entry
		if fs.isDir(full) then
			local contentPath = projectPathOf(full) or full
			-- uma pasta com init.luau vira o próprio ModuleScript (convenção do Rojo)
			local initFile = nil
			for _, candidate in ipairs({ "/init.luau", "/init.lua" }) do
				if fs.isFile(contentPath .. candidate) then
					initFile = contentPath .. candidate
				end
			end
			local node = Node.new(entry, parentNode, if initFile then "ModuleScript" else "Folder", initFile)
			addChild(parentNode, node)
			mountDir(contentPath, node)
		elseif entry:match("%.luau$") or entry:match("%.lua$") then
			local base = entry:gsub("%.luau$", ""):gsub("%.lua$", "")
			if base ~= "init" then
				local name, kind = scriptKindOf(base)
				addChild(parentNode, Node.new(name, parentNode, kind, full))
			end
		end
	end
end

local game
local services = {}

local function makeService(name)
	local svc = Node.new(name, nil, name, nil)
	services[name] = svc
	return svc
end

local function robloxRequire(target)
	if type(target) == "string" then
		return require(target)
	end
	local file = rawget(target, "_file")
	if not file then
		error("require: alvo não é um ModuleScript: " .. tostring(target and target:GetFullName()))
	end
	local cached = moduleCache[file]
	if cached ~= nil then
		if cached == "__loading__" then
			error("require cíclico em " .. file)
		end
		return cached
	end
	moduleCache[file] = "__loading__"
	local source = fs.readFile(file)
	local env = Loader.makeEnv(target)
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	if result == nil then
		result = true
	end
	moduleCache[file] = result
	return result
end

function Loader.makeEnv(scriptNode)
	local env = {}
	env.script = scriptNode
	env.require = robloxRequire
	env.game = game
	env.task = task
	env.tick = os.clock
	env.warn = function(...)
		print("[warn]", ...)
	end
	env.typeof = function(v)
		return typeof(v)
	end
	return env
end

function Loader.init(projectRoot)
	rootDir = projectRoot
	moduleCache = {}
	game = Node.new("game", nil, "DataModel", nil)
	function game:GetService(name)
		local svc = services[name]
		if not svc then
			svc = makeService(name)
		end
		return svc
	end
	local rs = makeService("ReplicatedStorage")
	local sss = makeService("ServerScriptService")
	local sp = makeService("StarterPlayer")
	local sps = Node.new("StarterPlayerScripts", sp, "StarterPlayerScripts", nil)
	addChild(sp, sps)
	local shared = Node.new("Shared", rs, "Folder", nil)
	addChild(rs, shared)
	mountDir(projectRoot .. "/src/shared", shared)
	local server = Node.new("Server", sss, "Folder", nil)
	addChild(sss, server)
	mountDir(projectRoot .. "/src/server", server)
	local client = Node.new("Client", sps, "Folder", nil)
	addChild(sps, client)
	mountDir(projectRoot .. "/src/client", client)
	-- dependências do Wally (Packages/ e ServerPackages/), quando já instaladas
	if fs.isDir(projectRoot .. "/Packages") then
		local packages = Node.new("Packages", rs, "Folder", nil)
		addChild(rs, packages)
		mountDir(projectRoot .. "/Packages", packages)
	end
	if fs.isDir(projectRoot .. "/ServerPackages") then
		local serverPackages = Node.new("ServerPackages", sss, "Folder", nil)
		addChild(sss, serverPackages)
		mountDir(projectRoot .. "/ServerPackages", serverPackages)
	end
	return game
end

function Loader.require(path)
	-- path no formato "Shared/Rules/Combat" ou "Server/Services/X"
	local node = nil
	for part in path:gmatch("[^/]+") do
		if node == nil then
			if part == "Shared" then
				node = services.ReplicatedStorage.Shared
			elseif part == "Server" then
				node = services.ServerScriptService.Server
			elseif part == "Client" then
				node = services.StarterPlayer.StarterPlayerScripts.Client
			elseif part == "Packages" then
				node = services.ReplicatedStorage.Packages
			elseif part == "ServerPackages" then
				node = services.ServerScriptService.ServerPackages
			else
				error("raiz desconhecida: " .. part)
			end
		else
			node = node[part]
		end
	end
	return robloxRequire(node)
end

function Loader.game()
	return game
end

return Loader
