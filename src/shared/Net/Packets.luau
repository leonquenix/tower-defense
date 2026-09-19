--!strict
-- Definição binária dos pacotes (ByteNet). Espelha exatamente os tipos de Net/Codec.
--
-- Por que ByteNet: o quadro de partida sai a 10 Hz para cada jogador com dezenas de inimigos.
-- Em tabela crua isso é texto repetido ("fiapo", "Preparation", "L3A") mais overhead de tabela;
-- aqui vira buffer com inteiros pequenos (Codec troca os textos por ids de Enums).
--
-- O que continua em `unknown`: respostas de comando e avisos de lobby (perfil, loja, grupo,
-- convites, resultado). São raros, de forma muito variável, e o servidor já valida tudo em
-- Net/Protocol antes de agir. Trocar essas mensagens por structs fixas custaria manutenção sem
-- ganho de banda mensurável.
--
-- Este módulo só pode ser exigido em runtime (o ByteNet abre RemoteEvents ao carregar). A lógica
-- testável fora do Studio mora em Net/Codec e Net/Protocol.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

-- As structs precisam nascer DENTRO do callback do namespace: o ByteNet registra a ordem de
-- criação para o cliente reconstruir o mesmo layout binário. Criar uma struct fora daqui
-- levanta "attempt to index nil" na primeira mensagem (foi o que aconteceu no primeiro teste).
return ByteNet.defineNamespace("quintal", function()
	local enemy = ByteNet.struct({
		id = ByteNet.uint32,
		d = ByteNet.uint8,
		b = ByteNet.bool,
		hp = ByteNet.float32,
		mhp = ByteNet.float32,
		s = ByteNet.float32,
		v = ByteNet.float32,
		sl = ByteNet.float32,
		mk = ByteNet.float32,
		sm = ByteNet.bool,
		tg = ByteNet.bool,
		tga = ByteNet.optional(ByteNet.float32),
		ab = ByteNet.float32,
		ar = ByteNet.float32,
		er = ByteNet.float32,
	})

	local tower = ByteNet.struct({
		id = ByteNet.uint32,
		o = ByteNet.float64, -- UserId não cabe com folga em uint32
		d = ByteNet.uint8,
		st = ByteNet.uint8,
		x = ByteNet.uint8,
		y = ByteNet.uint8,
		tm = ByteNet.uint8,
		inv = ByteNet.uint32,
		cp = ByteNet.optional(ByteNet.uint32),
		ci = ByteNet.uint8,
		du = ByteNet.float32,
	})

	local participant = ByteNet.struct({
		u = ByteNet.float64,
		n = ByteNet.string,
		c = ByteNet.bool,
		r = ByteNet.bool,
		sv = ByteNet.uint8,
		col = ByteNet.uint8,
	})

	local group = ByteNet.struct({ e = ByteNet.uint8, n = ByteNet.uint16 })

	local snapshot = ByteNet.struct({
		matchId = ByteNet.string,
		mode = ByteNet.uint8,
		map = ByteNet.uint8,
		diff = ByteNet.uint8,
		phase = ByteNet.uint8,
		wave = ByteNet.uint8,
		total = ByteNet.uint8,
		hp = ByteNet.float32,
		t = ByteNet.float32,
		speed = ByteNet.uint8,
		ends = ByteNet.float32,
		pulse = ByteNet.float32,
		rev = ByteNet.uint32,
		wallet = ByteNet.uint32,
		limit = ByteNet.uint8,
		placed = ByteNet.uint8,
		full = ByteNet.bool,
		unlockAll = ByteNet.bool,
		tutorial = ByteNet.uint8,
		enemies = ByteNet.array(enemy),
		towers = ByteNet.array(tower),
		parts = ByteNet.array(participant),
		preview = ByteNet.array(group),
	})

	local target = ByteNet.struct({ e = ByteNet.uint32, d = ByteNet.float32, i = ByteNet.uint8 })

	local event = ByteNet.struct({
		k = ByteNet.uint8,
		ks = ByteNet.optional(ByteNet.string),
		t = ByteNet.float32,
		entity = ByteNet.optional(ByteNet.uint32),
		tower = ByteNet.optional(ByteNet.uint32),
		seq = ByteNet.optional(ByteNet.uint32),
		user = ByteNet.optional(ByteNet.float64),
		amount = ByteNet.optional(ByteNet.float32),
		wave = ByteNet.optional(ByteNet.uint8),
		phase = ByteNet.optional(ByteNet.uint8),
		enemyDef = ByteNet.optional(ByteNet.uint8),
		circuit = ByteNet.optional(ByteNet.uint8),
		partner = ByteNet.optional(ByteNet.uint32),
		radius = ByteNet.optional(ByteNet.float32),
		s = ByteNet.optional(ByteNet.float32),
		resolveAt = ByteNet.optional(ByteNet.float32),
		expiresAt = ByteNet.optional(ByteNet.float32),
		cellX = ByteNet.optional(ByteNet.uint8),
		cellY = ByteNet.optional(ByteNet.uint8),
		reason = ByteNet.optional(ByteNet.string),
		code = ByteNet.optional(ByteNet.string),
		speed = ByteNet.optional(ByteNet.uint8),
		targets = ByteNet.array(target),
		entityIds = ByteNet.array(ByteNet.uint32),
		towerIds = ByteNet.array(ByteNet.uint32),
	})
	return {
		-- Cliente -> servidor: intenção com requestId e sequência de sessão.
		command = ByteNet.definePacket({
			value = ByteNet.struct({
				seq = ByteNet.uint32,
				id = ByteNet.string,
				action = ByteNet.string,
				payload = ByteNet.unknown,
			}),
		}),
		-- Servidor -> cliente: resposta correlacionada pelo requestId.
		result = ByteNet.definePacket({
			value = ByteNet.struct({
				id = ByteNet.string,
				ok = ByteNet.bool,
				code = ByteNet.optional(ByteNet.string),
				body = ByteNet.unknown,
			}),
		}),
		-- Servidor -> cliente, 10 Hz: estado da partida e eventos cosméticos do intervalo.
		frame = ByteNet.definePacket({
			value = ByteNet.struct({
				snap = snapshot,
				events = ByteNet.array(event),
			}),
		}),
		-- Servidor -> cliente: avisos raros da partida (tutorial, resultado, saída, revanche).
		matchInfo = ByteNet.definePacket({
			value = ByteNet.struct({
				kind = ByteNet.uint8,
				data = ByteNet.unknown,
			}),
		}),
		-- Servidor -> cliente: lobby, convites, perfil e loja.
		lobby = ByteNet.definePacket({
			value = ByteNet.struct({
				kind = ByteNet.uint8,
				data = ByteNet.unknown,
			}),
		}),
	}
end)
