#!/usr/bin/env bash
# ensure_uv_env.sh
#
# Idempotent setup/detection for a project-local uv-managed Python
# environment. Finds the nearest ancestor directory with a pyproject.toml
# (treating it as the project root), creates one plus a .venv if missing,
# and prints the resolved project root and venv Python path so the caller
# can confirm every subsequent command targets the local env, not a global
# interpreter.
#
# Exit codes:
#   0  success — PROJECT_ROOT and VENV_PYTHON printed
#   1  uv is not installed (prints MISSING_UV)
set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "MISSING_UV"
  exit 1
fi

# Walk upward from cwd looking for an existing pyproject.toml.
dir="$PWD"
root=""
while [ "$dir" != "/" ]; do
  if [ -f "$dir/pyproject.toml" ]; then
    root="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done
[ -z "$root" ] && root="$PWD"

cd "$root"

if [ ! -f "pyproject.toml" ]; then
  echo "No pyproject.toml in $root — running 'uv init --bare'." >&2
  # --bare avoids side effects that surprise users dropping into an existing
  # directory: no README.md, no main.py stub, no new git repo, no
  # .python-version pin unless one is wanted.
  uv init --bare --vcs none >/dev/null 2>&1 || uv init --bare --vcs none
fi

if [ ! -d ".venv" ]; then
  echo "No .venv in $root — running 'uv venv'." >&2
  uv venv >/dev/null 2>&1
fi

py_path="$(uv run python -c 'import sys; print(sys.executable)')"
echo "PROJECT_ROOT=$root"
echo "VENV_PYTHON=$py_path"
