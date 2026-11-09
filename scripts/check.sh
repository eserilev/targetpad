#!/usr/bin/env bash
# Runs the format check, the lint, and the tests.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
stylua --check addon
selene --quiet addon/Targetpad
luajit addon/tests/run.lua
echo "checks ok"
