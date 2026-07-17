# Migration Plan: Fork + Submodule Architecture

## Goal

Reduce maintenance burden of keeping neovim config in sync with upstream
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) while preserving all
custom plugins, Mason tools, keymaps, and options.

## Current State

- Single 1056-line `init.lua` with inline plugin configs
- Mixed `lua/kickstart/` (modular remnants) and `lua/custom/` (personal additions)
- Direct clone of upstream, heavily diverged — manual updates are painful

## Target State

Fork `dam9000/kickstart-modular.nvim` (`lazy` branch) to `Kardbord/kickstart.nvim`,
add it as a **git submodule** under `.config/nvim/` in the dotfiles repo.

The fork will contain the full neovim config with a clean separation:

```
.config/nvim/                          # git submodule → Kardbord/kickstart.nvim
├── init.lua                           # thin bootstrap (~60 lines)
├── lazy-lock.json
├── lua/
│   ├── options.lua                    # core options (extracted)
│   ├── keymaps.lua                    # basic keymaps (extracted)
│   ├── lazy-bootstrap.lua            # lazy.nvim auto-install
│   ├── lazy-plugins.lua              # plugin list
│   ├── kickstart/                     # upstream-sourced, updated via merge
│   │   └── plugins/
│   │       ├── lsp.lua                # LSP + Mason + conform
│   │       ├── cmp.lua                # nvim-cmp + luasnip
│   │       ├── telescope.lua
│   │       ├── which-key.lua
│   │       ├── mini.lua
│   │       ├── tokyonight.lua
│   │       ├── gitsigns.lua
│   │       ├── autopairs.lua
│   │       ├── indent_line.lua
│   │       ├── debug.lua
│   │       ├── comment.lua
│   │       ├── sleuth.lua
│   │       ├── todo-comments.lua
│   │       ├── lsp_lines.lua
│   │       └── neo-tree.lua
│   └── custom/                        # personal config, never touched by merges
│       ├── commands.lua               # UpdateAll command
│       ├── sandbox.lua                # firejail sandbox
│       ├── secrets.lua                # secret manager
│       └── plugins/
│           ├── avante.lua
│           ├── trouble.lua
│           ├── misc.lua
│           ├── nvim-ufo.lua
│           ├── render-markdown.lua
│           └── lazydev.lua
└── UPDATE-GUIDE.md                    # this file
```

## Why This Architecture

- **Modular per-file structure**: diffing upstream is `diff -r` against small files,
  not a 1000-line init.lua
- **Merge-friendly**: upstream changes land in `lua/kickstart/`; `lua/custom/` almost
  never conflicts
- **Self-contained**: the fork repo is the entire neovim config, nothing split across repos
- **Submodule is transparent**: `nvim` works exactly as before — Neovim just sees
  `.config/nvim/` as usual

## Why `dam9000/kickstart-modular.nvim` (`lazy` branch)

This fork of upstream already has:
- Modular file structure (`lua/options.lua`, `lua/keymaps.lua`, etc.)
- lazy.nvim (matches current setup — no vim.pack conversion needed)
- `lua/kickstart/` for base plugins
- `lua/custom/plugins/` placeholder for personal additions
- 109-line `init.lua` (just requires)

This avoids both "modularize a monolithic file" and "port vim.pack to lazy.nvim" as
separate steps.

## Step-by-Step

### Step 1: Create the Fork

1. Go to https://github.com/dam9000/kickstart-modular.nvim
2. Fork to `Kardbord/kickstart.nvim`
3. Default branch → `lazy` (not `master`)

### Step 2: Clone and Populate the Fork

```bash
git clone git@github.com:Kardbord/kickstart.nvim.git /tmp/kickstart-fork
cd /tmp/kickstart-fork
git checkout lazy
```

Replace/update files:

| File | Source |
|---|---|
| `lua/options.lua` | Extract from current `init.lua` (lines 93-171) |
| `lua/keymaps.lua` | Extract from current `init.lua` (lines 173-221) |
| `lua/lazy-bootstrap.lua` | Extract lazy bootstrap from current `init.lua` (lines 262-269) |
| `lua/kickstart/plugins/*.lua` | One file per plugin, extracted from current `init.lua` lazy block |
| `lua/custom/` | Copy from current `.config/nvim/lua/custom/` (unchanged) |
| `lazy-lock.json` | Copy from current `.config/nvim/lazy-lock.json` |

Then:

```bash
# Remove upstream docs (not needed in personal fork)
git rm -r .github/ doc/ README.md LICENSE.md
rm -rf scripts/           # if present

# Add UPDATE-GUIDE.md
# This file

git add -A
git commit -m "Initial config: migrate from monolithic init.lua to modular structure"
git push origin lazy
```

### Step 3: Extract init.lua Into Modular Files

For each plugin in the current `init.lua` `require('lazy').setup({...})`, create a
file in `lua/kickstart/plugins/`. Each file returns a plugin spec (or list of specs)
consumable by lazy.nvim's `import` mechanism.

For example, `lua/kickstart/plugins/lsp.lua` gets the LSP/Mason/conform block.
`lua/kickstart/plugins/cmp.lua` gets nvim-cmp + luasnip.

The `lazy-plugins.lua` file becomes:

```lua
require('lazy').setup({
  { import = 'kickstart.plugins' },
  { import = 'custom.plugins' },
}, {
  defaults = { version = '*' },
  -- icons, etc.
})
```

### Step 4: Replace Dotfiles Config with Submodule

```bash
cd /home/tkvarfordt/projects/dotfiles

# Extract history of .config/nvim into standalone branch (optional)
git subtree split --prefix=.config/nvim --branch nvim-history

# Remove the current nvim config
git rm -r .config/nvim

# Add as submodule
git submodule add git@github.com:Kardbord/kickstart.nvim.git .config/nvim
git submodule absorbgitdirs

# Commit
git add .gitmodules .config/nvim
git commit -m "Replace nvim config with submodule to Kardbord/kickstart.nvim"
```

### Step 5: Test

```bash
nvim  # should work exactly as before
:Lazy  # all 48 plugins present
```

### Step 6: Clean Up

- `:Lazy clean` — remove nvim-treesitter (built into Neovim 0.12+)
- Fix telescope branch in lockfile (locked at `0.1.x`, spec says `0.2.x`)

## Future Update Workflow

### When upstream `dam9000/kickstart-modular.nvim` updates:

```bash
cd /tmp
git clone git@github.com:Kardbord/kickstart.nvim.git
cd kickstart.nvim
git remote add upstream https://github.com/dam9000/kickstart-modular.nvim.git
git fetch upstream lazy
git merge upstream/lazy

# Conflicts are almost always in lua/kickstart/* and lua/options.lua/lua/keymaps.lua
# lua/custom/* should never conflict
# Resolve conflicts, test with nvim, then:
git push origin lazy
```

### When dotfiles need the update:

```bash
cd .config/nvim
git pull
cd ../..
git add .config/nvim
git commit -m "Update nvim config"
```
