#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PATH="$ROOT_DIR/tests/bin:$PATH"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is required but not installed" >&2
  exit 1
fi

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is required but not installed" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed" >&2
  exit 1
fi

if ! command -v bc >/dev/null 2>&1; then
  echo "bc is required but not installed" >&2
  exit 1
fi

sh_files=()
if command -v rg >/dev/null 2>&1; then
  while IFS= read -r file; do
    sh_files+=("$file")
  done < <(rg --files -g '*.sh' "$ROOT_DIR")
else
  while IFS= read -r file; do
    sh_files+=("$file")
  done < <(find "$ROOT_DIR" -type f -name '*.sh')
fi

sh_files+=("$ROOT_DIR/tests/bin/fake-claude" "$ROOT_DIR/tests/bin/fake-codex")

shellcheck -x "${sh_files[@]}"

if command -v rg >/dev/null 2>&1; then
  if ! rg --files -g '*.bats' "$ROOT_DIR/tests" >/dev/null 2>&1; then
    echo "No .bats tests found."
    exit 0
  fi
else
  if ! find "$ROOT_DIR/tests" -type f -name '*.bats' | grep -q .; then
    echo "No .bats tests found."
    exit 0
  fi
fi

bats "$ROOT_DIR/tests"
