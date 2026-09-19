#!/usr/bin/env bash
# Baixa as versões fixadas em rokit.toml para .toolchain/bin (macOS arm64 por padrão).
# Uso: bash tools/bootstrap_toolchain.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.toolchain/bin"
mkdir -p "$BIN"
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then ROJO_ARCH="macos-aarch64"; LUNE_ARCH="macos-aarch64"; STYLUA_ARCH="macos-aarch64"; else ROJO_ARCH="macos-x86_64"; LUNE_ARCH="macos-x86_64"; STYLUA_ARCH="macos-x86_64"; fi
fetch() { # nome url
  local name="$1" url="$2"
  if [[ -x "$BIN/$name" ]]; then echo "[ok] $name já presente"; return; fi
  echo "[..] baixando $name"
  curl -sL -o "$BIN/$name.zip" "$url"
  (cd "$BIN" && unzip -o -q "$name.zip" && rm -f "$name.zip")
  chmod +x "$BIN/$name"
}
fetch rojo "https://github.com/rojo-rbx/rojo/releases/download/v7.5.1/rojo-7.5.1-$ROJO_ARCH.zip"
fetch lune "https://github.com/lune-org/lune/releases/download/v0.9.3/lune-0.9.3-$LUNE_ARCH.zip"
fetch stylua "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.1.0/stylua-$STYLUA_ARCH.zip"
fetch luau-lsp "https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.69.0/luau-lsp-macos.zip"
fetch selene "https://github.com/Kampfkarren/selene/releases/download/0.31.0/selene-0.31.0-macos.zip"
fetch wally "https://github.com/UpliftGames/wally/releases/download/v0.3.2/wally-v0.3.2-macos.zip"
if [[ ! -f "$ROOT/.toolchain/globalTypes.d.luau" ]]; then
  curl -sL -o "$ROOT/.toolchain/globalTypes.d.luau" "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
fi
echo "Toolchain pronta em $BIN"
"$BIN/rojo" --version; "$BIN/lune" --version; "$BIN/stylua" --version; "$BIN/luau-lsp" --version; "$BIN/selene" --version; "$BIN/wally" --version
