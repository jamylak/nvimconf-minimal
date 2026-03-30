# nvimconf2

Tiny Neovim config with one plugin only: `fff.nvim` as a native package submodule, no package manager.

Main bindings: `:FFFFind`, `<C-Return>` for files, `<M-u>` for grep.

One-time setup after clone:

```sh
git submodule update --init --recursive
```

One-time `fff.nvim` binary install inside Neovim:

```vim
:FFFInstall
```

Try it:

```sh
XDG_CONFIG_HOME=/Users/james/proj NVIM_APPNAME=nvimconf2 nvim /Users/james/proj/vsdf -c "FFFFind"
```
