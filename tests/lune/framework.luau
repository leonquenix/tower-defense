--!nocheck
-- Mini framework de testes (describe/it/expect) com relatório em JSON.
local Framework = {}

local results = { suites = {}, passed = 0, failed = 0, failures = {} }
local currentSuite = nil

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function serialize(v)
	if type(v) == "table" then
		local parts = {}
		for k, x in pairs(v) do
			table.insert(parts, tostring(k) .. "=" .. serialize(x))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

function Framework.describe(name, fn)
	local previous = currentSuite
	currentSuite = { name = if previous then previous.name .. " / " .. name else name, tests = {} }
	table.insert(results.suites, currentSuite)
	fn()
	currentSuite = previous
end

function Framework.it(name, fn)
	assert(currentSuite, "it() fora de describe()")
	local ok, err = pcall(fn)
	local entry = { name = name, ok = ok, error = if ok then nil else tostring(err) }
	table.insert(currentSuite.tests, entry)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, currentSuite.name .. " :: " .. name .. " -> " .. tostring(err))
	end
end

function Framework.expect(actual)
	local matcher = {}
	function matcher.toBe(expected)
		if actual ~= expected then
			error(string.format("esperado %s, obtido %s", serialize(expected), serialize(actual)), 2)
		end
	end
	function matcher.toEqual(expected)
		if not deepEqual(actual, expected) then
			error(string.format("esperado %s, obtido %s", serialize(expected), serialize(actual)), 2)
		end
	end
	function matcher.toBeCloseTo(expected, tolerance)
		tolerance = tolerance or 1e-6
		if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
			error(
				string.format(
					"esperado ~%s (±%s), obtido %s",
					tostring(expected),
					tostring(tolerance),
					serialize(actual)
				),
				2
			)
		end
	end
	function matcher.toBeTruthy()
		if not actual then
			error("esperado valor verdadeiro, obtido " .. serialize(actual), 2)
		end
	end
	function matcher.toBeFalsy()
		if actual then
			error("esperado valor falso, obtido " .. serialize(actual), 2)
		end
	end
	function matcher.toBeNil()
		if actual ~= nil then
			error("esperado nil, obtido " .. serialize(actual), 2)
		end
	end
	function matcher.toBeGreaterThan(n)
		if not (type(actual) == "number" and actual > n) then
			error(string.format("esperado > %s, obtido %s", tostring(n), serialize(actual)), 2)
		end
	end
	function matcher.toBeLessThan(n)
		if not (type(actual) == "number" and actual < n) then
			error(string.format("esperado < %s, obtido %s", tostring(n), serialize(actual)), 2)
		end
	end
	function matcher.toThrow()
		local ok = pcall(actual)
		if ok then
			error("esperado erro, mas a função concluiu", 2)
		end
	end
	return matcher
end

function Framework.results()
	return results
end

return Framework
