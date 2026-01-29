# Ralph Looper

Clean, minimal structure with multi-backend AI support (Claude & Codex) and real-time streaming.

## Structure

```
.ralph/
├── ralph.sh                    # Main looper (root)
├── ralph-prompt.md             # Ralph system prompt
├── prd.json                    # Project requirements (JSON)
├── requirements.md             # Task breakdown (Markdown)
├── progress.txt                # Auto-generated loop log
├── findings.txt                # Append-only discoveries log
├── .tokens.json                # Token usage tracking
│
├── lib/
│   ├── config.sh              # Configuration (spinner, colors, limits)
│   ├── backend.sh             # Backend dispatcher (run_backend)
│   ├── backends/
│   │   ├── claude.sh          # Claude stream parser
│   │   └── codex.sh           # Codex stream parser
│   ├── utils.sh               # Utilities (spinner, streaming, helpers)
│   ├── tokens.sh              # Token tracking functions
│   └── ratelimit.sh           # Rate limit handling
│
├── templates/
│   ├── prd.json.template      # PRD template
│   ├── requirements.md.template # Requirements template
│   └── progress.txt.template   # Progress log template
│
├── write-a-prd.md             # PRD creation workflow (questions → output)
└── convert-prd.md             # Convert existing PRD → JSON/Markdown
```

## Quick Start

One-line install into an existing repo (installs to `.ralph/` and drops git history so it won't interfere with your project):

```bash
git clone --depth=1 https://github.com/Loa212/simple-ralph .ralph && rm -rf .ralph/.git
```

To refresh later: `rm -rf .ralph && git clone --depth=1 https://github.com/Loa212/simple-ralph .ralph && rm -rf .ralph/.git`

```bash
# Create structure
mkdir -p .ralph/{lib/backends,prompts,templates}

# Copy files
cp ralph.sh ralph-prompt.md prd.json requirements.md .ralph/
cp lib/*.sh .ralph/lib/
cp lib/backends/*.sh .ralph/lib/backends/
cp templates/* .ralph/templates/
cp prompts/* .ralph/prompts/

# Make executable
chmod +x .ralph/ralph.sh

# Run with Claude (default)
cd .ralph
./ralph.sh

# Run with Codex
RALPH_BACKEND=codex ./ralph.sh
```

## Backends

### Claude (default)

```bash
./ralph.sh
# or explicitly:
RALPH_BACKEND=claude ./ralph.sh
```

### Codex

```bash
RALPH_BACKEND=codex ./ralph.sh
```

## Workflow

### 1. Create a PRD (from scratch)

Use `write-a-prd.md` - asks questions one-by-one then outputs:

- `prd.json` - machine-readable tasks
- `requirements.md` - human-readable breakdown

### 2. Convert Existing PRD

Use `convert-prd.md` if you already have a PRD document from a PM or external source.

### 3. Run Ralph Looper

```bash
cd .ralph
./ralph.sh
```

Ralph will:

- Read `ralph-prompt.md`
- Stream AI output in real-time
- Extract status block
- Log to `progress.txt`
- Run one task per loop
- Exit when `EXIT_SIGNAL: true`

## Features

✅ **Multi-backend** - Claude or Codex via `RALPH_BACKEND` env var
✅ **Real-time streaming** - See output as it streams
✅ **Fun spinner** - 50+ rotating action words every 3 seconds
✅ **Task breakdown** - Golden "one small change" principle
✅ **Token tracking** - Logs to `.tokens.json`
✅ **Organized** - lib/, templates/, and prompts/ folders
✅ **Clean structure** - One main script, clear separation of concerns

## Config

### Environment Variables

Set these in your shell, CI environment, or a wrapper script. Env vars override built-in defaults.

**Precedence:** env vars > defaults.

| Variable                | Default              | Description                                                  |
| ----------------------- | -------------------- | ------------------------------------------------------------ |
| `RALPH_BACKEND`         | `claude`             | Backend to use (`claude` or `codex`)                         |
| `RALPH_LOOP_LIMIT`      | `30`                 | Max loop iterations (alias: `RALPH_MAX_LOOPS`)               |
| `RALPH_MAX_LOOPS`       | `30`                 | Max loop iterations (legacy, use `RALPH_LOOP_LIMIT`)         |
| `RALPH_FINDINGS_PATH`   | `$RALPH_DIR/findings.txt` | Path to the findings log file                           |
| `RALPH_RATE_LIMIT`      | `15`                 | Minutes to wait on rate limit (alias: `RALPH_RATE_LIMIT_WAIT`) |
| `RALPH_RATE_LIMIT_WAIT` | `15`                 | Minutes to wait on rate limit (legacy)                       |
| `RALPH_MAX_PARALLEL`    | `4`                  | Max parallel operations (available for backends/scripts)     |
| `RALPH_VERBOSE`         | `false`              | Enable verbose/debug logging (`true` or `1`)                 |
| `RALPH_DRY_RUN`         | `false`              | Show resolved config and exit without running (`true` or `1`)|
| `RALPH_NO_SPINNER`      | `false`              | Disable spinner output (`true` or `1`)                       |
| `RALPH_NOW_CMD`         | _(empty)_            | Command to print a deterministic UTC timestamp               |
| `SLEEP_CMD`             | _(empty)_            | Command to replace `sleep` in tests (e.g., `:`)              |
| `CLAUDE_CMD`            | _(see below)_        | Override Claude CLI command                                  |
| `CODEX_CMD`             | _(see below)_        | Override Codex CLI command                                   |

**Examples:**

```bash
# Run with verbose logging and a custom findings path
RALPH_VERBOSE=true RALPH_FINDINGS_PATH=./my-findings.txt ./ralph.sh

# Dry-run to verify configuration
RALPH_DRY_RUN=true RALPH_LOOP_LIMIT=10 ./ralph.sh

# Limit to 10 loops with Codex backend
RALPH_LOOP_LIMIT=10 RALPH_BACKEND=codex ./ralph.sh
```

### Backend Commands (lib/backends/)

**Claude** (`lib/backends/claude.sh`):

```bash
claude --dangerously-skip-permissions --print --verbose --output-format stream-json
```

**Codex** (`lib/backends/codex.sh`):

```bash
codex exec --json --dangerously-bypass-approvals-and-sandbox
```

Override any backend command by setting `CLAUDE_CMD` or `CODEX_CMD` in your environment.

## Testing

```bash
./tests/run.sh
```

The test harness is offline-friendly and runs shellcheck + bats. It covers:

- Unit tests (status parsing, token logging, rate-limit helpers)
- Integration tests (looper end-to-end with fake backends and fixtures)
- Live smoke tests (gated; off by default)

### Fake backends (offline)

Point Ralph at the fake backends and fixtures like this:

```bash
CLAUDE_CMD=./tests/bin/fake-claude \
FIXTURE=./tests/fixtures/claude/valid-stream.jsonl \
./ralph.sh
```

For multi-loop integration tests, you can provide a fixture sequence:

```bash
CLAUDE_CMD=./tests/bin/fake-claude \
FIXTURE_SEQUENCE=./tests/fixtures/claude/in-progress.jsonl:./tests/fixtures/claude/complete.jsonl:./tests/fixtures/claude/exit-signal.jsonl \
./ralph.sh
```

To avoid real waiting in tests, override sleep:

```bash
SLEEP_CMD=":" ./tests/run.sh
```

### Live smoke tests (gated)

Live smoke tests hit real backends and are skipped unless explicitly enabled.
Enable them with:

```bash
RUN_LIVE_TESTS=1 ./tests/run.sh
```

These tests only verify a single loop and confirm a status block exists. They are intentionally minimal to avoid cost and flakiness.

## Status Block (CRITICAL)

Ralph must output at end of every response:

```
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
TASKS_COMPLETED_THIS_LOOP: 0
FILES_MODIFIED: 0
TESTS_STATUS: NOT_RUN | PASSING | FAILING
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION | REFACTORING
EXIT_SIGNAL: false | true
RECOMMENDATION: [next step]
---END_RALPH_STATUS---
```

## Monitoring

```bash
# Watch progress
tail -f progress.txt

# Check status
tail -5 progress.txt | grep "STATUS:"

# View token usage
jq . .tokens.json
```

## Token Tracking

Automatically tracks per loop:

- Loop number
- Tokens used (input + output)
- Cost in USD
- Timestamp

## Adding New Backends

1. Create `lib/backends/mybackend.sh`:

```bash
#!/usr/bin/env bash
MYBACKEND_CMD="mybackend --json"

run_mybackend() {
    local prompt_file="$1"
    BACKEND_OUTPUT=""
    BACKEND_INPUT_TOKENS=0
    BACKEND_OUTPUT_TOKENS=0
    BACKEND_RATE_LIMITED=false
    BACKEND_RATE_LIMIT_MSG=""

    # Parse your backend's output format...
}
```

2. Add to `lib/backend.sh`:

```bash
source "$SCRIPT_DIR/backends/mybackend.sh"
# Add case in validate_backend() and run_backend()
```

## Notes

- Claude uses `--dangerously-skip-permissions` for file writes
- Codex uses `--dangerously-bypass-approvals-and-sandbox` for autonomous execution
- Streams output in real-time with fun spinner
- One task per loop (recommended)
- All progress logged to `progress.txt`
- Token usage tracked in `.tokens.json`

## Findings Log

Ralph appends discoveries (errors, surprises, lessons) to `findings.txt` using a fixed metadata template.
Entries are append-only and separated by `---`.

To generate AGENTS.md-ready fragments:

```bash
./lib/convert-findings.sh
```

This writes:

- `findings.fragments.yaml`
- `findings.fragments.json`
