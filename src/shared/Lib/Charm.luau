--!strict
-- Fachada tipada do Charm (Wally). Ver src/shared/Lib/Fusion.luau para o motivo do caminho fixo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inner = require(ReplicatedStorage.Packages._Index["littensy_charm@0.10.0"].charm)

export type Atom<T> = Inner.Atom<T>
export type Selector<T> = Inner.Selector<T>

return Inner
