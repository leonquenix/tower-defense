--!nocheck
-- Executa todos os specs em tests/specs com Lune: `lune run tests/run.luau`
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local Loader = require("./lune/loader")
local Framework = require("./lune/framework")

local root = process.cwd:gsub("/$", "")
if not fs.isDir(root .. "/src/shared") then
	error("Execute a partir da raiz do projeto (onde está default.project.json)")
end
Loader.init(root)

local filter = process.args[1]
local specDir = root .. "/tests/specs"
local files = fs.readDir(specDir)
table.sort(files)
local started = os.clock()
for _, file in ipairs(files) do
	if file:match("%.spec%.luau$") and (filter == nil or file:find(filter, 1, true)) then
		local source = fs.readFile(specDir .. "/" .. file)
		local env = Loader.makeEnv(nil)
		env.describe = Framework.describe
		env.it = Framework.it
		env.expect = Framework.expect
		env.load = Loader.require
		env.print = print
		local chunk = luau.load(source, { debugName = file, environment = env })
		local ok, err = pcall(chunk)
		if not ok then
			Framework.describe(file, function()
				Framework.it("carregamento do spec", function()
					error(err)
				end)
			end)
		end
	end
end
local elapsed = os.clock() - started
local results = Framework.results()
for _, suite in ipairs(results.suites) do
	local failed = 0
	for _, t in ipairs(suite.tests) do
		if not t.ok then
			failed += 1
		end
	end
	print(
		string.format(
			"%s %s (%d testes%s)",
			if failed == 0 then "PASS" else "FAIL",
			suite.name,
			#suite.tests,
			if failed > 0 then ", " .. failed .. " falhas" else ""
		)
	)
	for _, t in ipairs(suite.tests) do
		if not t.ok then
			print("   ✗ " .. t.name)
			print("     " .. tostring(t.error))
		end
	end
end
print(string.format("\n%d aprovados, %d reprovados em %.2fs", results.passed, results.failed, elapsed))
local summary = {
	passed = results.passed,
	failed = results.failed,
	failures = results.failures,
	suites = results.suites,
	elapsedSeconds = elapsed,
	timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}
fs.writeFile(root .. "/tests/last_run.json", serde.encode("json", summary, true))
if results.failed > 0 then
	process.exit(1)
end
