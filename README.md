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
└── prompts/
    └── convert-prd.md         # PRD → JSON/Markdown converter
```

## Quick Start

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

### 1. Break Down PRD into Tasks

```bash
# Use prompts/convert-prd.md
# Paste as system prompt in Claude
# Paste your raw PRD
# Claude outputs JSON + Markdown
# Update prd.json and requirements.md
```

### 2. Run Ralph Looper

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

| Variable                | Default  | Description                          |
| ----------------------- | -------- | ------------------------------------ |
| `RALPH_BACKEND`         | `claude` | Backend to use (`claude` or `codex`) |
| `RALPH_MAX_LOOPS`       | `30`     | Maximum loop iterations              |
| `RALPH_RATE_LIMIT_WAIT` | `15`     | Minutes to wait on rate limit        |

### Backend Commands (lib/backends/)

**Claude** (`lib/backends/claude.sh`):

```bash
claude --dangerously-skip-permissions --print --verbose --output-format stream-json
```

**Codex** (`lib/backends/codex.sh`):

```bash
codex exec --json --full-auto -
```

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
- Codex uses `--full-auto` for autonomous execution
- Streams output in real-time with fun spinner
- One task per loop (recommended)
- All progress logged to `progress.txt`
- Token usage tracked in `.tokens.json`
