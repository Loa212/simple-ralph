#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="$SCRIPT_DIR/findings.txt"
OUTPUT_YAML="$SCRIPT_DIR/findings.fragments.yaml"
OUTPUT_JSON="$SCRIPT_DIR/findings.fragments.json"

if [ ! -f "$INPUT_FILE" ]; then
  echo "findings.txt not found at $INPUT_FILE" >&2
  exit 1
fi

python3 - "$INPUT_FILE" "$OUTPUT_YAML" "$OUTPUT_JSON" <<'PY'
import json
import re
import sys

input_path, yaml_path, json_path = sys.argv[1:]

with open(input_path, "r", encoding="utf-8") as f:
    lines = f.read().splitlines()

entries = []
current = {}


def finalize():
    global current
    if current:
        entries.append(current)
        current = {}


line_idx = 0
while line_idx < len(lines):
    line = lines[line_idx]
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        line_idx += 1
        continue
    if stripped == "---":
        finalize()
        line_idx += 1
        continue
    match = re.match(r"^([A-Za-z0-9_]+)\s*:\s*(.*)$", line)
    if match:
        key = match.group(1)
        rest = match.group(2)
        if rest == "|":
            line_idx += 1
            block = []
            while line_idx < len(lines):
                next_line = lines[line_idx]
                next_stripped = next_line.strip()
                if next_stripped == "---" or re.match(r"^[A-Za-z0-9_]+\s*:\s*", next_line):
                    break
                if next_line.startswith("  "):
                    block.append(next_line[2:])
                elif next_line.startswith("\t"):
                    block.append(next_line[1:])
                else:
                    block.append(next_line)
                line_idx += 1
            current[key] = "\n".join(block).rstrip()
            continue
        value = rest.strip()
        if key == "tags":
            if value.startswith("[") and value.endswith("]"):
                inner = value[1:-1].strip()
                if inner:
                    parts = [p.strip().strip('"').strip("'") for p in inner.split(",")]
                    current[key] = [p for p in parts if p]
                else:
                    current[key] = []
            elif value:
                parts = [p.strip() for p in value.split(",")]
                current[key] = [p for p in parts if p]
            else:
                current[key] = []
        else:
            current[key] = value
        line_idx += 1
        continue
    line_idx += 1

finalize()

with open(yaml_path, "w", encoding="utf-8") as f:
    for entry in entries:
        f.write(f"- timestamp: {entry.get('timestamp', '')}\n")
        f.write(f"  source: {entry.get('source', '')}\n")
        f.write(f"  severity: {entry.get('severity', '')}\n")
        f.write(f"  summary: {entry.get('summary', '')}\n")

        details = entry.get("details", "")
        f.write("  details: |\n")
        if details:
            for line in details.replace("\r", "").splitlines():
                f.write(f"    {line}\n")
        else:
            f.write("    \n")

        reproduce = entry.get("reproduce", "")
        f.write("  reproduce: |\n")
        if reproduce:
            for line in reproduce.replace("\r", "").splitlines():
                f.write(f"    {line}\n")
        else:
            f.write("    \n")

        evidence = entry.get("evidence", "")
        f.write("  evidence: |\n")
        if evidence:
            for line in evidence.replace("\r", "").splitlines():
                f.write(f"    {line}\n")
        else:
            f.write("    \n")

        tags = entry.get("tags", [])
        if isinstance(tags, str):
            tags = [tags] if tags else []
        if tags:
            f.write("  tags:\n")
            for tag in tags:
                f.write(f"    - {tag}\n")
        else:
            f.write("  tags: []\n")

with open(json_path, "w", encoding="utf-8") as f:
    json.dump(entries, f, indent=2)
PY

echo "Wrote $OUTPUT_YAML and $OUTPUT_JSON"
