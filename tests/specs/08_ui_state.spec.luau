local Store = load("Client/UI/Store")
local Protocol = load("Shared/Net/Protocol")
local Localization = load("Shared/Config/Localization")

local function newInvite(id, expiresAt)
	return {
		inviteId = id,
		partyId = "p1",
		fromUserId = 10,
		fromName = "Ana",
		mapId = "jardim",
		difficulty = "normal",
		expiresAt = expiresAt,
		state = "pending",
	}
end

describe("Store / convites", function()
	it("um convite vencido deixa de ser aceitável e some depois da carência", function()
		Store.clear()
		Store.addInvite(newInvite("i1", 100))
		expect(#Store.get().invites).toBe(1)
		expect(Store.get().invites[1].state).toBe("pending")
		-- antes do prazo, nada muda
		Store.expireInvites(99)
		expect(Store.get().invites[1].state).toBe("pending")
		-- no prazo, vira expirado (o cartão explica em vez de sumir na cara do jogador)
		Store.expireInvites(100)
		expect(Store.get().invites[1].state).toBe("expired")
		-- passada a carência, sai da lista
		Store.expireInvites(104)
		expect(#Store.get().invites).toBe(0)
	end)

	it("não duplica o mesmo inviteId", function()
		Store.clear()
		Store.addInvite(newInvite("i2", 100))
		Store.addInvite(newInvite("i2", 100))
		expect(#Store.get().invites).toBe(1)
	end)

	it("responder remove o convite da lista", function()
		Store.clear()
		Store.addInvite(newInvite("i3", 100))
		Store.removeInvite("i3")
		expect(#Store.get().invites).toBe(0)
	end)

	it("cooldown por destinatário é de 5 s e não repete automaticamente", function()
		Store.clear()
		Store.markInviteSent(42, "sent")
		expect(Store.inviteCooldownLeft(42) > 0).toBeTruthy()
		expect(Store.inviteCooldownLeft(42) <= 5).toBeTruthy()
		expect(Store.inviteCooldownLeft(43)).toBe(0)
	end)
end)

describe("Store / conexão", function()
	it("2 s sem atualização é sinal instável e 5 s bloqueia mutações", function()
		Store.clear()
		Store.setConnection("ok")
		local base = os.clock()
		Store.noteFrame()
		expect(Store.updateConnection(base)).toBe("ok")
		expect(Store.canMutate()).toBeTruthy()

		local state = Store.get()
		state.lastFrameAt = base - 2.5
		expect(Store.updateConnection(base)).toBe("unstable")
		-- sinal instável ainda permite agir: o tabuleiro não é apagado no primeiro atraso
		expect(Store.canMutate()).toBeTruthy()

		state.lastFrameAt = base - 6
		expect(Store.updateConnection(base)).toBe("reconciling")
		expect(Store.canMutate()).toBe(false)
	end)

	it("um frame novo devolve o estado para ok", function()
		Store.clear()
		Store.setConnection("reconciling")
		Store.noteFrame()
		expect(Store.get().connection).toBe("ok")
	end)
end)

describe("Store / recompensa pendente", function()
	it("guarda e limpa o resultado pendente sem apagar o matchId", function()
		Store.clear()
		Store.setPendingResult({ matchId = "m1", status = "pending", buttons = 120 })
		expect(Store.get().pendingResult.matchId).toBe("m1")
		Store.setPendingResult(nil)
		expect(Store.get().pendingResult).toBeNil()
	end)
end)

describe("Protocol / RespondInvite", function()
	local function env(action, payload)
		return {
			protocolVersion = 1,
			sessionSequence = 1,
			requestId = "r1",
			action = action,
			payload = payload,
		}
	end

	it("aceita inviteId e accept bem formados", function()
		local ok, err = Protocol.validateEnvelope(env("RespondInvite", { inviteId = "abc123", accept = true }))
		expect(ok).toBeTruthy()
		expect(err).toBeNil()
	end)

	it("recusa resposta sem token ou com campo extra", function()
		expect(select(2, Protocol.validateEnvelope(env("RespondInvite", { accept = true })))).toBe("BAD_REQUEST")
		expect(
			select(2, Protocol.validateEnvelope(env("RespondInvite", { inviteId = "a", accept = true, partyId = "p" })))
		).toBe("BAD_REQUEST")
		expect(select(2, Protocol.validateEnvelope(env("RespondInvite", { inviteId = "a", accept = 1 })))).toBe(
			"BAD_REQUEST"
		)
	end)

	it("convite gasta o balde persistente, não o de combate", function()
		expect(Protocol.PERSISTENT_ACTIONS.RespondInvite).toBe(true)
		expect(Protocol.PERSISTENT_ACTIONS.InviteToParty).toBe(true)
		expect(Protocol.COMBAT_ACTIONS.RespondInvite).toBeNil()
	end)
end)

describe("Localização / textos da interface", function()
	it("nenhum texto entregue mostra o marcador de preço", function()
		for _, locale in ipairs(Localization.locales()) do
			Localization.setLocale(locale)
			-- o preço só aparece depois de vir da plataforma
			expect(Localization.get("shop.buy", { price = "199" }):find("{pre") == nil).toBeTruthy()
			expect(Localization.get("shop.priceIs", { price = "199" }):find("{") == nil).toBeTruthy()
		end
		Localization.setLocale("pt-br")
	end)

	it("todo código de erro do protocolo tem texto próprio", function()
		for _, code in pairs(Protocol.ERROR) do
			expect(Localization.has("error." .. code)).toBeTruthy()
		end
		-- código desconhecido cai no texto de reserva
		expect(Localization.has("error.UNKNOWN")).toBeTruthy()
	end)

	it("motivos de bloqueio de construção existem nos dois idiomas", function()
		for _, key in ipairs({ "build.onPath", "build.occupied", "build.limit", "build.noFunds", "build.invalidCell" }) do
			expect(Localization.has(key)).toBeTruthy()
		end
		expect(#Localization.missingKeys("en")).toBe(0)
	end)
end)
