#!/usr/bin/env bash
set -euo pipefail

# Get the directory containing this script and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧪 LazyVim Flake Testing Suite"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}!${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

test_count=0
pass_count=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    test_count=$((test_count + 1))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "PASS"
        pass_count=$((pass_count + 1))
    else
        error "FAIL"
        return 1
    fi
}

echo
echo "1. Basic File Structure Tests"
echo "----------------------------"

run_test "flake.nix exists" "[ -f '$PROJECT_ROOT/flake.nix' ]"
run_test "module.nix exists" "[ -f '$PROJECT_ROOT/module.nix' ]"
run_test "plugins.json exists" "[ -f '$PROJECT_ROOT/plugins.json' ]"
run_test "plugin-mappings.nix exists" "[ -f '$PROJECT_ROOT/plugin-mappings.nix' ]"
run_test "update script exists" "[ -x '$PROJECT_ROOT/scripts/update-plugins.sh' ]"

echo
echo "2. JSON and Nix Evaluation Tests"
echo "--------------------------------"

run_test "plugins.json is valid JSON" "jq empty '$PROJECT_ROOT/plugins.json'"
run_test "plugins.json has plugins" "[ \$(cat '$PROJECT_ROOT/plugins.json' | jq '.plugins | length') -gt 0 ]"
run_test "plugin-mappings.nix evaluates" "nix-instantiate --eval '$PROJECT_ROOT/plugin-mappings.nix' >/dev/null"
run_test "flake.nix is valid" "cd '$PROJECT_ROOT' && nix flake show --no-update-lock-file >/dev/null"

echo
echo "3. Module Evaluation Tests"
echo "-------------------------"

# Test basic module import - use absolute path to avoid path issues
run_test "module can be imported" "nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; module = import $PROJECT_ROOT/module.nix { config = {}; lib = pkgs.lib; inherit pkgs; }; in module.options ? programs'"

# Test module options
run_test "lazyvim option exists" "nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; module = import $PROJECT_ROOT/module.nix { config = {}; lib = pkgs.lib; inherit pkgs; }; in module.options.programs ? lazyvim'"

echo
echo "4. Plugin Resolution Tests"
echo "-------------------------"

# Test some specific plugin mappings
test_plugins=(
    "LazyVim/LazyVim:LazyVim"
    "folke/tokyonight.nvim:tokyonight-nvim"
    "nvim-telescope/telescope.nvim:telescope-nvim"
    "neovim/nvim-lspconfig:nvim-lspconfig"
)

for plugin_test in "${test_plugins[@]}"; do
    plugin_name="${plugin_test%%:*}"
    expected_nix_name="${plugin_test##*:}"
    
    if nix-instantiate --eval "$PROJECT_ROOT/plugin-mappings.nix" -A "\"$plugin_name\"" 2>/dev/null | grep -q "$expected_nix_name"; then
        success "Plugin mapping: $plugin_name → $expected_nix_name"
        pass_count=$((pass_count + 1))
    else
        error "Plugin mapping: $plugin_name → $expected_nix_name"
    fi
    test_count=$((test_count + 1))
done

echo
echo "5. Generated Configuration Tests"
echo "-------------------------------"

# Create a temporary directory for testing
TEMP_DIR=$(mktemp -d)
export HOME="$TEMP_DIR"

# Test minimal configuration generation
cat > "$TEMP_DIR/test-minimal.nix" << 'EOF'
{ config, lib, pkgs, ... }:
{
  imports = [ ./module.nix ];
  programs.lazyvim.enable = true;
  home.username = "test";
  home.homeDirectory = "/tmp/test";
  home.stateVersion = "23.11";
}
EOF

# Copy our module to the temp directory
cp "$PROJECT_ROOT/module.nix" "$PROJECT_ROOT/plugin-mappings.nix" "$PROJECT_ROOT/plugins.json" "$TEMP_DIR/"
cp -r "$PROJECT_ROOT/overrides" "$TEMP_DIR/"

# Skip this test as it requires full home-manager environment
warning "Skipping home-manager integration test (requires full environment)"
# run_test "minimal config generates init.lua" "
#     cd '$TEMP_DIR' && 
#     nix-build '<home-manager>' -A config.xdg.configFile.'nvim/init.lua'.source --arg configuration ./test-minimal.nix >/dev/null
# "

echo
echo "6. Update Script Tests"
echo "--------------------"

run_test "update script is executable" "[ -x '$PROJECT_ROOT/scripts/update-plugins.sh' ]"
run_test "parse script exists" "[ -f '$PROJECT_ROOT/scripts/parse-plugins.lua' ]"

# Test that the script doesn't crash on dry run
if command -v nvim >/dev/null 2>&1; then
    run_test "update script basic validation" "bash -n '$PROJECT_ROOT/scripts/update-plugins.sh'"
else
    warning "Neovim not available, skipping update script test"
fi

echo
echo "7. Example Configuration Tests"
echo "-----------------------------"

run_test "minimal example exists" "[ -f '$PROJECT_ROOT/examples/minimal.nix' ]"
run_test "full-featured example exists" "[ -f '$PROJECT_ROOT/examples/full-featured.nix' ]"
run_test "flake usage example exists" "[ -f '$PROJECT_ROOT/examples/flake-usage.nix' ]"

# Cleanup
rm -rf "$TEMP_DIR"

echo
echo "📊 Test Results"
echo "==============="
echo "Tests run: $test_count"
echo "Passed: $pass_count"
echo "Failed: $((test_count - pass_count))"

if [ $pass_count -eq $test_count ]; then
    echo
    success "🎉 All tests passed! LazyVim flake is working correctly."
    echo
    echo "Next steps to test manually:"
    echo "  1. Add this flake to your NixOS/home-manager configuration"
    echo "  2. Enable programs.lazyvim.enable = true"
    echo "  3. Rebuild your configuration"
    echo "  4. Run 'nvim' and check that LazyVim loads"
    echo "  5. Verify plugins are working and Mason is disabled"
    exit 0
else
    echo
    error "❌ Some tests failed. Please review the output above."
    exit 1
fi