# nvimconf2

Tiny Neovim config with one plugin only: `fff.nvim` as a native package submodule, no package manager.

Main bindings: `:FFFFind`, `<C-Return>` for files, `<M-u>` for grep.

One-time setup after clone:

```sh
git submodule update --init --recursive
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
