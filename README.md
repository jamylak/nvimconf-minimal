# nvimconf-minimal

🚧 Work in progress. I am still fixing it.

Minimal Neovim config focused on migrating `jamylak/nvimconf`, supporting Neovim `0.12.0+`, and staying faster and simpler by using builtin `vim.pack` for plugin management.

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

1. Recommended: put this repo at `~/.config/nvimconf-minimal` or symlink it there, then launch with `NVIM_APPNAME` only.

```sh
ln -s ~/proj/nvimconf-minimal ~/.config/nvimconf-minimal
```
2. Run it

```sh
NVIM_APPNAME=nvimconf-minimal nvim ~/proj/some-project -c "FFFFind"
```
