#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SOCKET="${TMPDIR:-/tmp}/$(basename "$(mktemp -u -t nvimconf-picker-mode)").sock"
UI_LOG=$(mktemp -t nvimconf-picker-mode-log)
STATE_FILE=$(mktemp -t nvimconf-picker-mode-state)
UI_PID=''

cleanup() {
  if [ -S "$SOCKET" ]; then
    nvim-0.12.0 --server "$SOCKET" --remote-expr "execute('qa!')" >/dev/null 2>&1 || true
  fi

  if [ -n "$UI_PID" ] && kill -0 "$UI_PID" 2>/dev/null; then
    kill "$UI_PID" 2>/dev/null || true
    wait "$UI_PID" 2>/dev/null || true
  fi

  rm -f "$SOCKET" "$UI_LOG" "$STATE_FILE"
}

trap cleanup EXIT INT TERM

wait_for_socket() {
  attempts=0
  while [ "$attempts" -lt 100 ]; do
    if [ -S "$SOCKET" ]; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 0.1
  done

  cat "$UI_LOG" >&2 || true
  echo "timed out waiting for Neovim socket $SOCKET" >&2
  return 1
}

picker_state() {
  : >"$STATE_FILE"
  nvim-0.12.0 --server "$SOCKET" --remote-expr "writefile([&filetype . ':' . mode(1)], '$STATE_FILE')" >/dev/null 2>&1 || true
  cat "$STATE_FILE" 2>/dev/null || true
}

wait_for_state() {
  expected=$1
  attempts=0
  while [ "$attempts" -lt 100 ]; do
    actual=$(picker_state 2>/dev/null || true)
    if [ "$actual" = "$expected" ]; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 0.1
  done

  echo "expected picker state $expected, got ${actual:-<unavailable>}" >&2
  cat "$UI_LOG" >&2 || true
  return 1
}

cd "$REPO_DIR"

script -q /dev/null "$SCRIPT_DIR/launch_worktree.sh" --listen "$SOCKET" README.md >"$UI_LOG" 2>&1 &
UI_PID=$!

wait_for_socket
wait_for_state 'markdown:n'

nvim-0.12.0 --server "$SOCKET" --remote-send '<M-Space>'
wait_for_state 'penguin-prompt:i'

nvim-0.12.0 --server "$SOCKET" --remote-send '<M-o>'
wait_for_state 'nvimconf-minimal_oldfiles_picker:i'

nvim-0.12.0 --server "$SOCKET" --remote-send '<M-n>'
wait_for_state 'nvimconf-minimal_project_picker:i'

echo 'picker insert-mode test passed'
