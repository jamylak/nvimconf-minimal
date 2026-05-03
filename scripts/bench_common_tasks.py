#!/usr/bin/env python3

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT_BIN = "/usr/bin/script"
NVIM_BIN = "nvim-0.12.0"
DEFAULT_TIMEOUT_SECONDS = 15
REPO_DIR = Path(__file__).resolve().parent.parent


def lua_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def repo_files(repo_dir: Path, limit: int) -> list[str]:
    files: list[str] = []
    for path in sorted(repo_dir.rglob("*")):
        if len(files) >= limit:
            break
        if not path.is_file():
            continue
        if ".git" in path.parts:
            continue
        files.append(str(path))
    return files


def wait_for(filetype: str) -> str:
    return (
        "local ok = vim.wait(5000, function() "
        f"return vim.bo.filetype == {lua_string(filetype)} "
        "end, 10); "
        "if not ok then vim.cmd('cquit') end"
    )


def diffview_ready() -> str:
    return (
        "local ok = vim.wait(5000, function() "
        "for _, buf in ipairs(vim.api.nvim_list_bufs()) do "
        "if vim.api.nvim_buf_get_name(buf):match('^diffview://') then return true end "
        "end "
        "return false "
        "end, 10); "
        "if not ok then vim.cmd('cquit') end"
    )


def neogit_log_ready() -> str:
    return (
        "local ok = vim.wait(5000, function() "
        "for _, buf in ipairs(vim.api.nvim_list_bufs()) do "
        "if vim.bo[buf].filetype == 'NeogitLogView' then return true end "
        "end "
        "return false "
        "end, 10); "
        "if not ok then vim.cmd('cquit') end"
    )


def scenarios(repo_dir: Path) -> list[dict[str, object]]:
    oldfiles = repo_files(repo_dir, 80)
    oldfiles_lua = "{ " + ", ".join(lua_string(path) for path in oldfiles) + " }"

    return [
    {
        "name": "empty-startup",
        "label": "Open empty Neovim",
        "args": [],
        "ready_lua": "",
    },
    {
        "name": "fffind",
        "label": "Open with -c FFFFind",
        "args": ["-c", "FFFFind"],
        "ready_lua": wait_for("fff_input"),
    },
    {
        "name": "project-picker",
        "label": "Open project picker",
        "args": [
            "-c",
            "lua require('nvimconf.project_picker').open()",
        ],
        "ready_lua": wait_for("nvimconf-minimal_project_picker"),
    },
    {
        "name": "oldfiles-picker",
        "label": "Open oldfiles picker",
        "args": [
            "-c",
            f"lua vim.v.oldfiles = {oldfiles_lua}; require('nvimconf.oldfiles_picker').open()",
        ],
        "ready_lua": wait_for("nvimconf-minimal_oldfiles_picker"),
    },
    {
        "name": "neogit-diff",
        "label": "Open with -c NeogitDiff",
        "args": ["-c", "NeogitDiff"],
        "ready_lua": diffview_ready(),
    },
    {
        "name": "neogit-diff-main",
        "label": "Open with -c NeogitDiffMain",
        "args": ["-c", "NeogitDiffMain"],
        "ready_lua": diffview_ready(),
    },
    {
        "name": "neogit-log",
        "label": "Open with -c NeogitLog",
        "args": ["-c", "NeogitLog"],
        "ready_lua": neogit_log_ready(),
    },
    ]


def make_env(repo_dir: Path, config_home: str, state_home: str, cache_home: str) -> dict[str, str]:
    env = os.environ.copy()
    env["NVIM_APPNAME"] = repo_dir.name
    env["XDG_CONFIG_HOME"] = config_home
    env["XDG_STATE_HOME"] = state_home
    env["XDG_CACHE_HOME"] = cache_home
    return env


def command_prefix(headless: bool) -> list[str]:
    if headless:
        return [NVIM_BIN, "--headless"]
    return [SCRIPT_BIN, "-q", "/dev/null", NVIM_BIN]


def ensure_config_home(repo_dir: Path, config_home: str) -> None:
    config_link = Path(config_home) / repo_dir.name
    config_link.parent.mkdir(parents=True, exist_ok=True)
    if config_link.exists() or config_link.is_symlink():
        config_link.unlink()
    config_link.symlink_to(repo_dir)


def run_command(repo_dir: Path, args: list[str], env: dict[str, str], headless: bool, timeout: float) -> None:
    command = [*command_prefix(headless), *args]
    completed = subprocess.run(
        command,
        cwd=repo_dir,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=timeout,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"benchmark command failed: {' '.join(command)}")


def report_progress(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def run_once(
    repo_dir: Path,
    scenario: dict[str, object],
    env: dict[str, str],
    result_dir: str,
    headless: bool,
    timeout: float,
) -> float:
    result_path = Path(result_dir) / f"{scenario['name']}.txt"
    if result_path.exists():
        result_path.unlink()

    ready_lua = scenario["ready_lua"]
    ready_prefix = f"{ready_lua}; " if ready_lua else ""
    final_lua = (
        "lua "
        f"{ready_prefix}"
        f"vim.fn.writefile({{ string.format('%.3f', (vim.uv.hrtime() - _G.nvimconf_bench_start_ns) / 1e6) }}, {lua_string(str(result_path))})"
    )
    command = [
        *command_prefix(headless),
        "--cmd",
        "lua _G.nvimconf_bench_start_ns = vim.uv.hrtime()",
        *scenario["args"],
        "-c",
        final_lua,
        "-c",
        "qa!",
    ]
    completed = subprocess.run(
        command,
        cwd=repo_dir,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=timeout,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"benchmark command failed: {' '.join(command)}")

    return float(result_path.read_text().strip())


def summarize(samples: list[float]) -> dict[str, float]:
    return {
        "median_ms": round(statistics.median(samples), 2),
        "mean_ms": round(statistics.fmean(samples), 2),
        "min_ms": round(min(samples), 2),
        "max_ms": round(max(samples), 2),
    }


def benchmark(repo_dir: Path, iterations: int, warmup: int, headless: bool, timeout: float) -> list[dict[str, object]]:
    with tempfile.TemporaryDirectory(prefix="nvimconf-bench-config-") as config_home, tempfile.TemporaryDirectory(
        prefix="nvimconf-bench-state-"
    ) as state_home, tempfile.TemporaryDirectory(prefix="nvimconf-bench-cache-") as cache_home, tempfile.TemporaryDirectory(
        prefix="nvimconf-bench-results-"
    ) as result_dir:
        ensure_config_home(repo_dir, config_home)
        env = make_env(repo_dir, config_home, state_home, cache_home)
        results = []

        selected_scenarios = scenarios(repo_dir)
        for index, scenario in enumerate(selected_scenarios, start=1):
            report_progress(f"[{index}/{len(selected_scenarios)}] {scenario['label']}")
            prepare_args = scenario.get("prepare_args")
            if prepare_args:
                report_progress("  preparing...")
                run_command(repo_dir, prepare_args, env, headless, timeout)

            for warmup_index in range(1, warmup + 1):
                report_progress(f"  warmup {warmup_index}/{warmup}")
                run_once(repo_dir, scenario, env, result_dir, headless, timeout)

            samples = []
            for sample_index in range(1, iterations + 1):
                report_progress(f"  sample {sample_index}/{iterations}")
                samples.append(run_once(repo_dir, scenario, env, result_dir, headless, timeout))
            results.append(
                {
                    "name": scenario["name"],
                    "label": scenario["label"],
                    "samples_ms": [round(sample, 2) for sample in samples],
                    **summarize(samples),
                }
            )

        return results


def print_table(results: list[dict[str, object]]) -> None:
    print("| Scenario | Median ms | Mean ms | Min ms | Max ms |")
    print("| --- | ---: | ---: | ---: | ---: |")
    for result in results:
        print(
            f"| {result['label']} | {result['median_ms']:.2f} | {result['mean_ms']:.2f} | "
            f"{result['min_ms']:.2f} | {result['max_ms']:.2f} |"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark common startup and picker tasks for this config.")
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--format", choices=("table", "json"), default="table")
    parser.add_argument("--headless", action="store_true", help="Run nvim --headless instead of through a pty.")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument("--repo-dir", type=Path, default=REPO_DIR)
    args = parser.parse_args()

    results = benchmark(args.repo_dir.resolve(), args.iterations, args.warmup, args.headless, args.timeout)
    if args.format == "json":
        print(json.dumps(results, indent=2))
    else:
        print_table(results)


if __name__ == "__main__":
    main()
