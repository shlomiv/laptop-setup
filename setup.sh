#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

echo "╔══════════════════════════════════╗"
echo "║       Laptop Setup Script        ║"
echo "╚══════════════════════════════════╝"
echo

# Run all modules (skip _common.sh)
for module in "$MODULES_DIR"/*.sh; do
    [[ "$(basename "$module")" == _* ]] && continue
    echo "────────────────────────────────────"
    echo "Running: $(basename "$module" .sh)"
    echo "────────────────────────────────────"
    bash "$module"
    echo
done

echo "════════════════════════════════════"
echo "Setup complete."
