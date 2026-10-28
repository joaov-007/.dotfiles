#!/usr/bin/env bash
# One gate for cg.py: tests, format, lint, security, dead code.
#   ./check.sh          check only
#   ./check.sh --fix    apply formatting and safe lint fixes first
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

need() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "missing $1 — sudo pacman -S --needed $2" >&2
		exit 1
	}
}

need python3 python
need ruff ruff
need bandit bandit
need vulture vulture

if [[ "${1:-}" == "--fix" ]]; then
	ruff format .
	ruff check --fix .
fi

echo "== tests =="
python3 -m unittest -q test_cg.py

echo "== format =="
ruff format --check .

echo "== lint =="
ruff check .

echo "== security =="
bandit -q -r . -x ./__pycache__

echo "== dead code =="
vulture --min-confidence 80 cg.py test_cg.py

echo "== completions =="
for sh in bash zsh fish; do
	command -v "$sh" >/dev/null 2>&1 || continue
	python3 cg.py completions "$sh" | "$sh" -n
	echo "  $sh ok"
done

echo "all green"
