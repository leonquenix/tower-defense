--!strict
-- Só troca a textura de um sprite por um quadro (antecipação, disparo, segundo passo, efeito) que
-- o Roblox já carregou de verdade. Quadro que falhou (moderação, rede, ID removido) nunca aparece:
-- o sprite fica na pose, que é o visual que já existia, em vez de piscar vazio no meio do ataque.
--
-- O pedido é feito uma vez por conteúdo e em segundo plano; quem desenha só pergunta `ready`.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local FramePreload = {}

type Status = "loading" | "ready" | "failed"

local status: { [string]: Status } = {}

-- Contagens publicadas como atributos do jogador local (QG_FramesReady/Failed/Loading): dá para
-- conferir no Studio pela árvore ou por execute_luau, sem depender do cache de módulos do jogo.
local function publish()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local ready, failed, loading = 0, 0, 0
	for _, s in pairs(status) do
		if s == "ready" then
			ready += 1
		elseif s == "failed" then
			failed += 1
		else
			loading += 1
		end
	end
	player:SetAttribute("QG_FramesReady", ready)
	player:SetAttribute("QG_FramesFailed", failed)
	player:SetAttribute("QG_FramesLoading", loading)
end

function FramePreload.request(ids: { string })
	local batch: { string } = {}
	for _, id in ipairs(ids) do
		if id ~= "" and status[id] == nil then
			status[id] = "loading"
			table.insert(batch, id)
		end
	end
	if #batch == 0 then
		return
	end
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync(batch, function(contentId: string, fetch: Enum.AssetFetchStatus)
				status[contentId] = if fetch == Enum.AssetFetchStatus.Success then "ready" else "failed"
			end)
		end)
		for _, id in ipairs(batch) do
			if status[id] == "loading" then
				-- PreloadAsync voltou sem resposta para este conteúdo (ou levantou erro)
				status[id] = if ok then "ready" else "failed"
			end
		end
		publish()
	end)
end

function FramePreload.ready(id: string?): boolean
	return id ~= nil and id ~= "" and status[id] == "ready"
end

-- Diagnóstico (console de teste e verificação no Studio).
function FramePreload.counts(): (number, number, number)
	local ready, failed, loading = 0, 0, 0
	for _, s in pairs(status) do
		if s == "ready" then
			ready += 1
		elseif s == "failed" then
			failed += 1
		else
			loading += 1
		end
	end
	return ready, failed, loading
end

function FramePreload.failedIds(): { string }
	local list: { string } = {}
	for id, s in pairs(status) do
		if s == "failed" then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

return FramePreload
