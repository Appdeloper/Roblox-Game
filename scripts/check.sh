#!/usr/bin/env bash
# Runs every offline check CI runs: format, lint, unit tests, Rojo build.
# Usage: scripts/check.sh            (tools from PATH, e.g. installed by `rokit install`)
#        BIN=~/tools scripts/check.sh (tools from a folder)
set -euo pipefail
cd "$(dirname "$0")/.."

tool() {
	if [[ -n "${BIN:-}" && -x "$BIN/$1" ]]; then echo "$BIN/$1"; else command -v "$1"; fi
}

STYLUA=$(tool stylua)
SELENE=$(tool selene)
LUAU=$(tool luau)
ROJO=$(tool rojo)

echo "==> stylua --check"
"$STYLUA" --check src tests

if [[ ! -f roblox.yml ]]; then
	echo "==> generating selene roblox std"
	"$SELENE" generate-roblox-std
fi
echo "==> selene"
"$SELENE" src
"$SELENE" --config tests/selene.toml tests

echo "==> luau tests"
"$LUAU" tests/run.luau

echo "==> rojo build"
mkdir -p build
"$ROJO" build default.project.json -o build/DontLookBackstage.rbxl

echo "All checks passed."
