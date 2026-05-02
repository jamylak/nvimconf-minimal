#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

run_case() {
  command_name=$1
  expected_filetype=$2

  "$SCRIPT_DIR/launch_worktree.sh" --headless \
    -c "$command_name" \
    -c "lua local ok = vim.wait(5000, function() return vim.bo.filetype == '$expected_filetype' end, 10); if not ok then error('expected $expected_filetype from $command_name, got ' .. vim.bo.filetype) end" \
    -c qa >/dev/null
}

run_case Oldfiles nvimconf-minimal_oldfiles_picker
run_case ProjectPicker nvimconf-minimal_project_picker

echo 'picker launch command test passed'
