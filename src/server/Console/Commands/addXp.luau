--!strict
-- Definição do comando (replicada ao cliente pelo Cmdr). Soma XP de conta para conferir subida
-- de nível, torres liberadas e recompensas. Quem executa é `addXpServer`.
return {
	Name = "addXp",
	Aliases = { "xp" },
	Description = "Soma XP à conta (sobe nível, libera torres e entrega as recompensas do nível).",
	Group = "Teste",
	Args = {
		{
			Type = "integer",
			Name = "amount",
			Description = "Quanto XP somar.",
		},
	},
}
