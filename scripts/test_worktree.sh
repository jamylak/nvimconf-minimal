#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_NAME="nvimconf2"
CONFIG_LINK="$HOME/.config/$APP_NAME"

mkdir -p "$HOME/.config"

if [ -L "$CONFIG_LINK" ]; then
  CURRENT_TARGET=$(readlink "$CONFIG_LINK" || true)
  if [ "$CURRENT_TARGET" != "$REPO_DIR" ]; then
    ln -sfn "$REPO_DIR" "$CONFIG_LINK"
  fi
elif [ -e "$CONFIG_LINK" ]; then
  echo "$CONFIG_LINK exists and is not a symlink; refusing to overwrite" >&2
  exit 1
else
  ln -s "$REPO_DIR" "$CONFIG_LINK"
fi

exec env NVIM_APPNAME="$APP_NAME" nvim-0.12.0 "$@"
