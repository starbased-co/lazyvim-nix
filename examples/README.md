# LazyVim Standalone Mode Examples

Ready-to-use templates for plugin testing and CI/CD.

## Files

### Plugin Testing

- **`plugin-test.nix`** - Comprehensive plugin testing template
  - Multiple test targets (load, setup, suite, all)
  - Interactive development shell
  - CI-ready single test
  - Usage: `nix-build plugin-test.nix -A <target>`

- **`ci-minimal.nix`** - Minimal CI test (copy-paste ready)
  - Single file, zero dependencies
  - Drop into any plugin repo
  - Usage: `nix-build ci-minimal.nix`

### CI/CD Workflows

- **`github-actions.yml`** - GitHub Actions workflow
  - Multi-job setup (lint, test, integration)
  - Matrix testing (multiple Neovim versions)
  - Cachix integration
  - Place in: `.github/workflows/test.yml`

- **`gitlab-ci.yml`** - GitLab CI configuration
  - Multi-stage pipeline
  - Artifact caching
  - Performance testing
  - Place in: `.gitlab-ci.yml`

### Complete Examples

- **`test-environment.nix`** - Full-featured test environment
  - All LazyVim features enabled
  - Custom launcher scripts
  - Quick validation test
  - Usage: `nix-build test-environment.nix -A <target>`

## Quick Start

### 1. Test Your Plugin

```bash
# Copy template to your plugin repo
cp examples/plugin-test.nix your-plugin/tests/

# Edit: Change "your-plugin" to your plugin name
vim your-plugin/tests/plugin-test.nix

# Run tests
cd your-plugin
nix-build tests/plugin-test.nix -A testAll
```

### 2. Setup CI (GitHub)

```bash
# Copy workflow
mkdir -p .github/workflows
cp examples/github-actions.yml .github/workflows/test.yml

# Edit: Adjust plugin name and test paths
vim .github/workflows/test.yml

# Commit and push
git add .github/workflows/test.yml
git commit -m "Add CI testing"
git push
```

### 3. Setup CI (GitLab)

```bash
# Copy config
cp examples/gitlab-ci.yml .gitlab-ci.yml

# Edit: Adjust plugin name
vim .gitlab-ci.yml

# Commit and push
git add .gitlab-ci.yml
git commit -m "Add CI testing"
git push
```

## Usage Patterns

### Pattern 1: Quick Validation

```bash
# Fastest test - just check plugin loads
nix-build examples/ci-minimal.nix
```

### Pattern 2: Comprehensive Testing

```bash
# Run all tests
nix-build examples/plugin-test.nix -A testAll

# Run specific tests
nix-build examples/plugin-test.nix -A testLoad
nix-build examples/plugin-test.nix -A testSetup
nix-build examples/plugin-test.nix -A testSuite
```

### Pattern 3: Interactive Development

```bash
# Enter development shell
nix-shell examples/plugin-test.nix -A shell

# Inside shell, Neovim uses test config
nvim
```

### Pattern 4: CI Integration

```bash
# Single command for CI
nix-build examples/plugin-test.nix -A testCI

# Or minimal version
nix-build examples/ci-minimal.nix
```

## Customization

### Change Plugin Name

In `plugin-test.nix`, replace all instances of `your-plugin`:

```nix
plugins = {
  your-plugin = ''  # <- Change this
    return {
      dir = "${pluginSrc}",
      config = function()
        require("your-plugin").setup()  # <- And this
      end,
    }
  '';
};
```

### Add Dependencies

```nix
plugins = {
  your-plugin = ''
    return {
      dir = "${pluginSrc}",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
      },
      config = function()
        require("your-plugin").setup()
      end,
    }
  '';

  # Make dependencies available
  plenary = ''return { "nvim-lua/plenary.nvim" }'';
  telescope = ''return { "nvim-telescope/telescope.nvim" }'';
};
```

### Add Treesitter

```nix
treesitterGrammars = let
  parsers = pkgs.symlinkJoin {
    name = "test-parsers";
    paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
      p.tree-sitter-lua
      p.tree-sitter-nix
    ])).dependencies;
  };
in parsers;
```

### Enable LazyVim Extras

For full module approach (not minimal CI):

```nix
# In home-manager or devenv
programs.lazyvim = {
  enable = true;
  standalone.enable = true;

  extras = {
    lang.lua.enable = true;
    coding.luasnip.enable = true;
  };
};
```

## Troubleshooting

**Q: "your-plugin" module not found**
A: Change `your-plugin` to your actual plugin module name in the config.

**Q: Tests pass locally but fail in CI**
A: Ensure Nix is properly installed in CI. Use `cachix/install-nix-action@v24` for GitHub.

**Q: How to debug test failures?**
A: Run interactively:

```bash
nix-shell examples/plugin-test.nix -A shell
nvim --version
nvim -u test-nvim/init.lua
```

**Q: Build is slow**
A: Use Cachix for caching:

- GitHub: `cachix/cachix-action@v12`
- GitLab: Pre-install cachix in before_script

**Q: Need to test against Neovim nightly?**
A: Override pkgs.neovim:

```nix
buildInputs = [ pkgs.neovim-nightly ];
```

## Reference

- Full documentation: `../STANDALONE-MODE.md`
- Integration tests: `../test-standalone-integration.nix`
- Simple tests: `../test-standalone-simple.nix`
- Implementation: `../lib/build-standalone.nix`

## Support

For issues or questions:

- Open an issue on the lazyvim-nix repository
- Check the main documentation
- Review test files for working examples
