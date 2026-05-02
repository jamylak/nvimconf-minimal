#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
TEST_WORKTREE="$SCRIPT_DIR/launch_worktree.sh"

run_nvim() {
  "$TEST_WORKTREE" --headless "$@" -c qa
}

validate_diff_command() {
  command_name=$1

  run_nvim \
    -c 'lua
      local command_name = "'"$command_name"'"
      local ok, err = pcall(function()
        vim.cmd(command_name)
        vim.cmd("sleep 500m")

        local has_diffview = false
        local has_neogit_status = false

        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(buf)
          local filetype = vim.bo[buf].filetype

          if name:match("^diffview://") then
            has_diffview = true
          end

          if filetype == "NeogitStatus" then
            has_neogit_status = true
          end
        end

        assert(has_diffview, "expected Diffview buffer for " .. command_name)
        assert(not has_neogit_status, "unexpected Neogit status buffer for " .. command_name)
      end)

      if not ok then
        print(err)
        vim.cmd("cquit")
      end
    '
}

validate_log_command() {
  run_nvim \
    -c 'lua
      local ok, err = pcall(function()
        vim.cmd.NeogitLog()
        vim.cmd("sleep 500m")

        local log_view = require("neogit.buffers.log_view")
        local instance = assert(log_view.instance, "expected NeogitLogView instance")
        local has_diffview = false

        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(buf):match("^diffview://") then
            has_diffview = true
          end
        end

        assert(instance:commit_count() == 50, "expected 50 initial log commits")
        assert(type(instance.fetch_func) == "function", "expected log fetch-more callback")
        assert(has_diffview, "expected Diffview buffer for NeogitLog")
      end)

      if not ok then
        print(err)
        vim.cmd("cquit")
      end
    '
}

time_command() {
  command_name=$1

  run_nvim \
    -c 'lua
      local command_name = "'"$command_name"'"
      local t = vim.uv.hrtime()
      local ok, err = pcall(vim.cmd[command_name])

      if not ok then
        print(err)
        vim.cmd("cquit")
      end

      print(command_name .. " cmd_ms", (vim.uv.hrtime() - t) / 1e6)
    '
}

validate_diff_command NeogitDiff
validate_diff_command NeogitDiffMain
validate_log_command

time_command NeogitDiff
time_command NeogitDiffMain
time_command NeogitLog
