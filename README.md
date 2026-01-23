# Ralph Looper - Claude Edition

Clean, minimal structure with Claude integration and real-time streaming.

## Structure

```
.ralph/
├── ralph.sh                    # Main looper (root)
├── prd.json                    # Project requirements (JSON)
├── requirements.md             # Task breakdown (Markdown)
├── progress.txt                # Auto-generated loop log
├── .tokens.json                # Token usage tracking
│
├── lib/
│   ├── config.sh              # Configuration (Claude command, spinner, colors)
│   ├── utils.sh               # Utilities (spinner, streaming, helpers)
│   └── tokens.sh              # Token tracking functions
│
└── prompts/
    ├── PROMPT.md              # Ralph system prompt
    └── convert-prd.md         # PRD → JSON/Markdown converter
```

## Quick Start

```bash
# Create structure
mkdir -p .ralph/{lib,prompts}

# Copy files
cp ralph.sh prd.json requirements.md .ralph/
cp lib/* .ralph/lib/
cp prompts/* .ralph/prompts/

# Make executable
chmod +x .ralph/ralph.sh

# Run
cd .ralph
./ralph.sh
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
- Read `prompts/PROMPT.md`
- Stream Claude output in real-time
- Extract status block
- Log to `progress.txt`
- Run one task per loop
- Exit when `EXIT_SIGNAL: true`

## Features

✅ **Uses Claude** - `claude --dangerously-skip-permissions`
✅ **Real-time streaming** - See output as it streams
✅ **Fun spinner** - 50+ rotating action words every 3 seconds
✅ **Task breakdown** - Golden "one small change" principle
✅ **Token tracking** - Logs to `.tokens.json`
✅ **Minimal** - Just copy 9 files
✅ **Clean structure** - lib/ for code, prompts/ for prompts

## Config (lib/config.sh)

```bash
CLAUDE_CMD="claude --dangerously-skip-permissions"
MAX_LOOPS=30
```

Edit to customize.

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

## Notes

- Uses `claude --dangerously-skip-permissions` for file writes
- Streams output in real-time with fun spinner
- One task per loop (recommended)
- All progress logged to `progress.txt`
- Token usage tracked in `.tokens.json`
