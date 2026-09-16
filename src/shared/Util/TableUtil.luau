--!strict
local TableUtil = {}

-- Cópia profunda de tabelas simples (sem metatables nem ciclos), usada para checkpoints.
function TableUtil.deepClone(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = TableUtil.deepClone(v)
	end
	return copy
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function TableUtil.removeValue(list: { any }, value: any): boolean
	local idx = table.find(list, value)
	if idx then
		table.remove(list, idx)
		return true
	end
	return false
end

function TableUtil.keys(t: { [any]: any }): { any }
	local list = {}
	for k in pairs(t) do
		table.insert(list, k)
	end
	return list
end

return TableUtil
