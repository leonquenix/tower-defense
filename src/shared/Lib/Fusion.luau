--!strict
-- Fachada tipada do Fusion (Wally). Requer o caminho fixado do índice porque o arquivo de
-- ligação gerado pelo Wally indexa o pacote em tempo de execução e o analisador não consegue
-- seguir os tipos por ali. `tools/check_package_facades.py` compara estas versões com wally.lock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inner = require(ReplicatedStorage.Packages._Index["elttob_fusion@0.3.0"].fusion)

export type Scope<Constructors = any> = Inner.Scope<Constructors>
export type Value<T, S = T> = Inner.Value<T, S>
export type Computed<T> = Inner.Computed<T>
export type StateObject<T> = Inner.StateObject<T>
export type UsedAs<T> = Inner.UsedAs<T>
export type Use = Inner.Use
export type Child = Inner.Child
export type Observer = Inner.Observer
export type Spring<T> = Inner.Spring<T>
export type Tween<T> = Inner.Tween<T>
export type Animatable = Inner.Animatable

return Inner
