# nvimconf2

Tiny Neovim config for current Neovim, using builtin `vim.pack` for plugin management.

Main bindings: `:FFFFind`, `<C-Return>` for files, `<M-u>` for grep.

Requirements:

```sh
git
neovim 0.12.0+
```

On first start, Neovim installs managed plugins through `vim.pack`.

If plugin install fails, run:

```vim
:lua vim.pack.update()
:restart
```

The `fff.nvim` native binary auto-installs on first use. If you want to do it manually instead, run `:FFFInstall`.

Alternative Launch:

1. Recommended: put this repo at `~/.config/nvimconf2` or symlink it there, then launch with `NVIM_APPNAME` only.

```sh
ln -s /Users/james/proj/nvimconf2 ~/.config/nvimconf2
```
2. Run it

```sh
NVIM_APPNAME=nvimconf2 nvim /Users/james/proj/vsdf -c "FFFFind"
```
