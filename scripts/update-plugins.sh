#!/usr/bin/env bash
set -euo pipefail

# LazyVim plugin update script
# This script fetches the latest LazyVim plugin specifications and generates plugins.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR=$(mktemp -d)
LAZYVIM_REPO="https://github.com/LazyVim/LazyVim.git"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "==> Cloning LazyVim repository..."
git clone --depth 1 "$LAZYVIM_REPO" "$TEMP_DIR/LazyVim"

echo "==> Getting LazyVim version..."
cd "$TEMP_DIR/LazyVim"
LAZYVIM_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "main")
LAZYVIM_COMMIT=$(git rev-parse HEAD)

echo "    Version: $LAZYVIM_VERSION"
echo "    Commit: $LAZYVIM_COMMIT"

echo "==> Extracting plugin specifications..."
cd "$REPO_ROOT"

# Run the Lua parser script
nvim --headless -u NONE \
    -c "set runtimepath+=$TEMP_DIR/LazyVim" \
    -c "luafile $SCRIPT_DIR/parse-plugins.lua" \
    -c "lua ParseLazyVimPlugins('$TEMP_DIR/LazyVim', '$REPO_ROOT/plugins.json.tmp', '$LAZYVIM_VERSION', '$LAZYVIM_COMMIT')" \
    -c "quit" 2>/dev/null || {
        echo "Error: Failed to parse LazyVim plugins"
        exit 1
    }

# Validate the generated JSON
if ! jq . "$REPO_ROOT/plugins.json.tmp" > /dev/null 2>&1; then
    echo "Error: Generated plugins.json is not valid JSON"
    exit 1
fi

# Check if we got any plugins
PLUGIN_COUNT=$(jq '.plugins | length' "$REPO_ROOT/plugins.json.tmp")
if [ "$PLUGIN_COUNT" -eq 0 ]; then
    echo "Error: No plugins found in generated JSON"
    exit 1
fi

echo "==> Found $PLUGIN_COUNT plugins"

# Move the temporary file to the final location
mv "$REPO_ROOT/plugins.json.tmp" "$REPO_ROOT/plugins.json"

echo "==> Successfully updated plugins.json"
echo "    Version: $LAZYVIM_VERSION"
echo "    Plugins: $PLUGIN_COUNT"

# Generate a summary of changes if plugins.json already existed
if git diff --quiet plugins.json 2>/dev/null; then
    echo "==> No changes detected"
else
    echo "==> Changes detected:"
    git diff --stat plugins.json 2>/dev/null || true
fi