--!strict
-- Fachada tipada do Trove (Wally): limpeza determinística de conexões e instâncias.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inner = require(ReplicatedStorage.Packages._Index["sleitnick_trove@1.8.0"].trove)

export type Trove = Inner.Trove

return Inner
