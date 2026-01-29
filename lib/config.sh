#!/usr/bin/env bash
# Ralph config
# shellcheck disable=SC2034

# Ralph directory (where all ralph files live)
# This is set by ralph.sh and used by all libs
RALPH_DIR="${RALPH_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Backend selection: claude | codex (set via RALPH_BACKEND env var)
# Usage: RALPH_BACKEND=codex ./ralph.sh

# Configuration
# Precedence: env vars > defaults
MAX_LOOPS=${RALPH_LOOP_LIMIT:-${RALPH_MAX_LOOPS:-30}}
RATE_LIMIT_WAIT_MINUTES=${RALPH_RATE_LIMIT:-${RALPH_RATE_LIMIT_WAIT:-15}}
FINDINGS_PATH=${RALPH_FINDINGS_PATH:-"${RALPH_DIR}/findings.txt"}
MAX_PARALLEL=${RALPH_MAX_PARALLEL:-4}
VERBOSE=${RALPH_VERBOSE:-false}
DRY_RUN=${RALPH_DRY_RUN:-false}
RALPH_NO_SPINNER=${RALPH_NO_SPINNER:-false}
RALPH_NOW_CMD=${RALPH_NOW_CMD:-}
SLEEP_CMD=${SLEEP_CMD:-}

# Verbose logging helper
verbose_log() {
    if [[ "$VERBOSE" == "true" || "$VERBOSE" == "1" ]]; then
        echo -e "${BLUE}[verbose]${NC} $*" >&2
    fi
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Spinner
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINNER_PID=""

SPINNER_WORDS=(
    "Bamboozling"
    "Sibidubing"
    "Percolating"
    "Badabiming"
    "Populating"
    "Conjuring"
    "Manifesting"
    "Synthesizing"
    "Transmuting"
    "Wrangling"
    "👉Fingering👌"
    "Summoning"
    "Orchestrating"
    "Brewing"
    "Concocting"
    "Materializing"
    "Shimshaming"
    "Razzledazzling"
    "Hocuspocusing"
    "Abracadabring"
    "Alakazaming"
    "Zippitydooing"
    "Whizbangifying"
    "Kerfuffling"
    "Discombobulating"
    "Flibbertigibbeting"
    "Gobbledygooking"
    "Hullaballooing"
    "Jiggerypokerying"
    "Lolligagging"
    "Malarkeying"
    "Nambyambying"
    "Pitterpattering"
    "Rambunctifying"
    "Skedaddling"
    "Wibblewobblin"
    "Zigzagging"
    "✊Wanking💦"
    "Bippityboppitying"
    "Splendiferous-ing"
    "Thingamabobbing"
    "Whatchamacalling"
    "Dinglehopping"
    "Snarfblating"
    "Woozlewazzling"
    "Snickerdoodling"
    "Flimflamming"
    "Hobnobbing"
    "Rigmaroling"
    "Wishy-washying"
    "Hodgepodging"
    "Humdinging"
)
