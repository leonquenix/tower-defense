--!strict
-- Definição do comando (replicada ao cliente pelo Cmdr).
return {
	Name = "setHealth",
	Aliases = { "setHp", "hp" },
	Description = "Define a vida do Farol na partida em andamento. Zero derruba na hora.",
	Group = "Teste",
	Args = {
		{
			Type = "integer",
			Name = "health",
			Description = "Quanta vida o Farol passa a ter.",
		},
	},
}
