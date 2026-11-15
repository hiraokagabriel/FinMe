#!/usr/bin/env bash
# Portão de qualidade do FinMe: format + analyze + test. Imprime "CHECK OK" no sucesso.
set -uo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  for d in "../flutter/bin" "/e/Projetos/FinMe/flutter/bin"; do
    [ -x "$d/flutter" ] && export PATH="$(cd "$d" && pwd):$PATH" && break
  done
fi
command -v flutter >/dev/null 2>&1 || { echo "CHECK FAIL: flutter não encontrado"; exit 1; }

dart format lib test >/dev/null || { echo "CHECK FAIL: format"; exit 1; }
if ! flutter analyze --no-pub lib test; then echo "CHECK FAIL: analyze"; exit 1; fi
if ! flutter test --no-pub -r failures-only; then echo "CHECK FAIL: test"; exit 1; fi
echo "CHECK OK"
