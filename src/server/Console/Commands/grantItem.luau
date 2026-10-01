--!strict
-- Definição do comando (replicada ao cliente pelo Cmdr). Dá ou tira fichas do inventário para
-- testar Retomada e Reforço sem passar pela compra. Quem executa é `grantItemServer`.
return {
	Name = "grantItem",
	Aliases = { "item", "tokens" },
	Description = "Soma fichas ao inventário (retry = Retomada, support = Reforço). Negativo tira.",
	Group = "Teste",
	Args = {
		{
			Type = "string",
			Name = "item",
			Description = "retry ou support",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Quantas fichas somar (negativo tira).",
			Default = 1,
		},
	},
}
