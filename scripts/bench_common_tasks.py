#!/usr/bin/env python3

import argparse
import json
import os
import statistics
import subprocess
import tempfile
from pathlib import Path


REPO_DIR = Path(__file__).resolve().parent.parent
APP_NAME = REPO_DIR.name
SCRIPT_BIN = "/usr/bin/script"
NVIM_BIN = "nvim-0.12.0"


def lua_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def repo_files(limit: int) -> list[str]:
    files: list[str] = []
    for path in sorted(REPO_DIR.rglob("*")):
        if len(files) >= limit:
            break
        if not path.is_file():
            continue
        if ".git" in path.parts:
            continue
        files.append(str(path))
    return files


OLDFILES = repo_files(80)
OLDFILES_LUA = "{ " + ", ".join(lua_string(path) for path in OLDFILES) + " }"


def wait_for(filetype: str) -> str:
    return (
        "local ok = vim.wait(5000, function() "
        f"return vim.bo.filetype == {lua_string(filetype)} "
        "end, 10); "
        "if not ok then vim.cmd('cquit') end"
    )


SCENARIOS = [
    {
        "name": "empty-startup",
        "label": "Open empty Neovim",
        "args": [],
        "ready_lua": "",
    },
    {
        "name": "fffind",
        "label": "Open with -c FFFFind",
        "prepare_args": [
            "-c",
            "lua require('nvimconf.fff').find_files()",
            "-c",
            "lua " + wait_for("fff_input"),
            "-c",
            "qa",
        ],
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
            f"lua vim.v.oldfiles = {OLDFILES_LUA}; require('nvimconf.oldfiles_picker').open()",
        ],
        "ready_lua": wait_for("nvimconf-minimal_oldfiles_picker"),
    },
]


def make_env(config_home: str, state_home: str) -> dict[str, str]:
    env = os.environ.copy()
    env["NVIM_APPNAME"] = APP_NAME
    env["XDG_CONFIG_HOME"] = config_home
    env["XDG_STATE_HOME"] = state_home
    return env


def ensure_config_home(config_home: str) -> None:
    config_link = Path(config_home) / APP_NAME
    config_link.parent.mkdir(parents=True, exist_ok=True)
    if config_link.exists() or config_link.is_symlink():
        config_link.unlink()
    config_link.symlink_to(REPO_DIR)


def run_command(args: list[str], env: dict[str, str]) -> None:
    command = [SCRIPT_BIN, "-q", "/dev/null", NVIM_BIN, *args]
    completed = subprocess.run(
        command,
        cwd=REPO_DIR,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"benchmark command failed: {' '.join(command)}")


def run_once(scenario: dict[str, object], env: dict[str, str], result_dir: str) -> float:
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
        SCRIPT_BIN,
        "-q",
        "/dev/null",
        NVIM_BIN,
        "--cmd",
        "lua _G.nvimconf_bench_start_ns = vim.uv.hrtime()",
        *scenario["args"],
        "-c",
        final_lua,
        "-c",
        "qa",
    ]
    completed = subprocess.run(
        command,
        cwd=REPO_DIR,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
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


def benchmark(iterations: int, warmup: int) -> list[dict[str, object]]:
    with tempfile.TemporaryDirectory(prefix="nvimconf-bench-config-") as config_home, tempfile.TemporaryDirectory(
        prefix="nvimconf-bench-state-"
    ) as state_home, tempfile.TemporaryDirectory(prefix="nvimconf-bench-results-") as result_dir:
        ensure_config_home(config_home)
        env = make_env(config_home, state_home)
        results = []

        for scenario in SCENARIOS:
            prepare_args = scenario.get("prepare_args")
            if prepare_args:
                run_command(prepare_args, env)

            for _ in range(warmup):
                run_once(scenario, env, result_dir)

            samples = [run_once(scenario, env, result_dir) for _ in range(iterations)]
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
    args = parser.parse_args()

    results = benchmark(args.iterations, args.warmup)
    if args.format == "json":
        print(json.dumps(results, indent=2))
    else:
        print_table(results)


if __name__ == "__main__":
    main()
