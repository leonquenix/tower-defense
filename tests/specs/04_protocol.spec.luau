local Protocol = load("Shared/Net/Protocol")

local function env(action, payload, extra)
	local e = { protocolVersion = 1, sessionSequence = 1, requestId = "r1", action = action, payload = payload }
	for k, v in pairs(extra or {}) do
		e[k] = v
	end
	return e
end

describe("Protocol / validação de envelope", function()
	it("aceita PlaceTower bem formado", function()
		local ok, err = Protocol.validateEnvelope(env("PlaceTower", { matchId = "m", towerId = "dardo", x = 3, y = 3 }))
		expect(ok).toBeTruthy()
		expect(err).toBeNil()
	end)
	it("P09: rejeita NaN, infinito, strings enormes e campos desconhecidos", function()
		expect(
			select(
				2,
				Protocol.validateEnvelope(env("PlaceTower", { matchId = "m", towerId = "dardo", x = 0 / 0, y = 3 }))
			)
		).toBe("BAD_REQUEST")
		expect(
			select(
				2,
				Protocol.validateEnvelope(env("PlaceTower", { matchId = "m", towerId = "dardo", x = math.huge, y = 3 }))
			)
		).toBe("BAD_REQUEST")
		expect(
			select(
				2,
				Protocol.validateEnvelope(
					env("PlaceTower", { matchId = string.rep("a", 500), towerId = "dardo", x = 1, y = 3 })
				)
			)
		).toBe("BAD_REQUEST")
		expect(
			select(
				2,
				Protocol.validateEnvelope(
					env("PlaceTower", { matchId = "m", towerId = "dardo", x = 1, y = 3, damage = 999 })
				)
			)
		).toBe("BAD_REQUEST")
		expect(
			select(
				2,
				Protocol.validateEnvelope(env("PlaceTower", { matchId = "m", towerId = "dardo", x = 1.5, y = 3 }))
			)
		).toBe("BAD_REQUEST")
	end)
	it("P08: não existe ação que aceite preço, dano ou recompensa", function()
		for action, schema in pairs(Protocol.ACTIONS) do
			expect(schema.price).toBeNil()
			expect(schema.damage).toBeNil()
			expect(schema.reward).toBeNil()
			expect(schema.buttons).toBeNil()
		end
	end)
	it("rejeita tabelas profundas e chaves extras no envelope", function()
		expect(select(2, Protocol.validateEnvelope(env("SetLoadout", { towerIds = { { "dardo" } } })))).toBe(
			"BAD_REQUEST"
		)
		expect(select(2, Protocol.validateEnvelope(env("CastPulse", { matchId = "m" }, { extra = 1 })))).toBe(
			"BAD_REQUEST"
		)
		expect(select(2, Protocol.validateEnvelope("string"))).toBe("BAD_REQUEST")
		expect(select(2, Protocol.validateEnvelope(env("Hack", {})))).toBe("BAD_REQUEST")
	end)
	it("exige campos obrigatórios e aceita opcionais ausentes", function()
		expect(select(2, Protocol.validateEnvelope(env("PlaceTower", { matchId = "m", towerId = "dardo", x = 1 })))).toBe(
			"BAD_REQUEST"
		)
		expect(Protocol.validateEnvelope(env("StartMatch", { mapId = "jardim", mode = "normal" }))).toBeTruthy()
	end)
end)

describe("Protocol / limite de taxa e deduplicação", function()
	it("balde permite rajada e recupera com o tempo", function()
		local b = Protocol.newBucket(10, 20, 0)
		local accepted = 0
		for _ = 1, 25 do
			if Protocol.takeToken(b, 0) then
				accepted += 1
			end
		end
		expect(accepted).toBe(20)
		expect(Protocol.takeToken(b, 0.05)).toBe(false)
		expect(Protocol.takeToken(b, 0.15)).toBe(true)
	end)
	it("T02: repetir requestId devolve a resposta anterior", function()
		local w = Protocol.newDedupe()
		local prev = Protocol.checkDedupe(w, "abc", 1)
		expect(prev).toBeNil()
		Protocol.remember(w, "abc", 1, { ok = true, entityId = 7 })
		local again = Protocol.checkDedupe(w, "abc", 1)
		expect(again.entityId).toBe(7)
	end)
	it("sequência antiga fora da janela é STALE_REQUEST", function()
		local w = Protocol.newDedupe()
		for i = 1, 200 do
			Protocol.remember(w, "r" .. i, i, { ok = true })
		end
		expect(#w.order).toBe(128)
		local _, err = Protocol.checkDedupe(w, "novo", 10)
		expect(err).toBe("STALE_REQUEST")
		local _, err2 = Protocol.checkDedupe(w, "novo2", 150)
		expect(err2).toBeNil()
	end)
end)
