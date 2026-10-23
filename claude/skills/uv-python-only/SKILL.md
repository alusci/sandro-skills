---
name: uv-python-only
description: Forces all Python code execution, script/test running, and package installation to go through a project-local uv-managed virtual environment (uv run / uv add / uv pip) instead of system python, python3, pip, pipx, conda, or pyenv. Use this skill any time you are about to run a Python script, execute a module, run pytest/unittest, start a REPL, install or upgrade a Python package, or invoke any `python`/`pip`/`conda` command in Bash — even if the user didn't mention "uv" explicitly. Also trigger it when a project has no virtual environment yet and Python code needs to run, or when you notice a bare `python`/`pip` command about to be issued.
---

# uv-only Python execution

## Why this matters

Running Python directly against whatever interpreter happens to be first on
`PATH` (system Python, a stray conda env, a pyenv shim) is how "works on my
machine" bugs happen and how system Python quietly gets polluted with
project-specific packages. `uv` gives every project its own `.venv` pinned to
a lockfile, created and reproduced in milliseconds. Once a project has a uv
environment, there is no good reason to ever fall back to a global
interpreter — so treat that as a hard rule, not a preference: **every Python
execution and every dependency install for this project must go through
`uv run` / `uv add` / `uv pip`, targeting the local `.venv`.**

## Step 1 — Make sure a local uv environment exists

Before running any Python, check whether the project already has one:
- a `pyproject.toml` at or above the current directory, and
- a `.venv/` next to it.

Run the bundled helper to detect and, if needed, create both in one shot:

```bash
bash <skill_dir>/scripts/ensure_uv_env.sh
```

(`<skill_dir>` is this skill's own directory.) It walks upward from the
current directory for the nearest `pyproject.toml`, and:
- if `uv` itself is missing, it prints `MISSING_UV` and exits 1 — see Step 4.
- if no `pyproject.toml` exists, it runs `uv init` to create one.
- if no `.venv` exists, it runs `uv venv` to create one.
- on success it prints `PROJECT_ROOT=...` and `VENV_PYTHON=...`.

Do this once per session/project, not before every single command — once you
know the env exists, just use it.

If the project already has Python dependencies declared another way
(`requirements.txt`, `setup.py`, a conda `environment.yml`), don't migrate
the whole project unless asked. It's enough that `.venv` exists locally; for
requirements.txt-based projects, install into that `.venv` with
`uv pip install -r requirements.txt` (Step 3) rather than converting to
`pyproject.toml`-based dependency management.

## Step 2 — Run everything through `uv run`

Never call `python`, `python3`, `py`, or an interpreter from a conda/pyenv
env directly. Always prefix with `uv run`, which transparently resolves to
the project's `.venv` (creating/syncing it first if needed):

| Instead of...                  | Do this                              |
|---------------------------------|---------------------------------------|
| `python script.py`             | `uv run python script.py`            |
| `python3 -m mymodule`          | `uv run python -m mymodule`          |
| `pytest` / `python -m pytest`  | `uv run pytest`                      |
| `python` (REPL)                | `uv run python`                      |
| `jupyter notebook`             | `uv run jupyter notebook`            |
| a standalone script with no project | `uv run --script script.py` (uv reads any inline PEP 723 dependency metadata in the script itself) |

If a command fails because a package is missing, the fix is to add the
dependency (Step 3) — not to reach for the system interpreter that happens
to already have it installed globally.

## Step 3 — Install dependencies into the local env only

- Project has `pyproject.toml` (the common case): use `uv add <package>`.
  This updates `pyproject.toml` and `uv.lock` and installs into `.venv` —
  this is the uv equivalent of `pip install` and should be your default.
- Project is `requirements.txt`-only and you don't want to restructure it:
  use `uv pip install <package>` (and `uv pip install -r requirements.txt`
  to sync). This still installs into the local `.venv`, just without the
  lockfile workflow.
- Never use `pip install` / `pip3 install` / `sudo pip install` / `conda
  install` / `pipx install <library>` for project dependencies — those write
  to a global or unrelated environment.
- Removing a dependency: `uv remove <package>` (pyproject-based projects).

## Step 4 — If `uv` isn't installed at all

Check with `command -v uv`. If it's missing, tell the user and offer to
install it rather than silently falling back to system Python:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # macOS/Linux
# or: brew install uv                             # macOS with Homebrew
```

After installing, re-run `scripts/ensure_uv_env.sh` to set up the
environment, then continue with Steps 1–3. Confirm installation succeeded
(`uv --version`) before proceeding — don't assume the install worked.

## Edge cases

- **Monorepo / multiple sub-projects**: use the `pyproject.toml` nearest to
  the code you're actually running, not necessarily the repo root. Run
  `uv run` from that sub-project's directory (or pass `--directory`).
- **One-off script, no project context requested**: still prefer
  `uv run --script`, which works even without a `pyproject.toml` by using
  an ephemeral/cached environment — this keeps even throwaway scripts off
  the system interpreter.
- **User explicitly asks to use system Python / a specific existing venv /
  conda**: that's their call to make for their own machine — follow their
  explicit instruction, but mention that it bypasses the project's uv
  environment so they know what changed.
- **Verifying you're actually in the local env** (useful when debugging
  "wrong package version" issues): `uv run python -c "import sys;
  print(sys.executable)"` should print a path inside `.venv`, not
  `/usr/bin/python3` or a conda path.
