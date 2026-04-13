#!/bin/bash
# publish.sh — Push all specs in harnesses that contain spec.yaml
# Usage: ./publisher/publish.sh [--dry-run] [--filter <name>]

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/publish_${TIMESTAMP}.log"

# ── Helpers ────────────────────────────────────────────────────────────────────
log()  { echo -e "$*" | tee -a "$LOG_FILE"; }
info() { log "${CYAN}  ℹ ${RESET} $*"; }
ok()   { log "${GREEN}  ✔ ${RESET} $*"; }
warn() { log "${YELLOW}  ⚠ ${RESET} $*"; }
err()  { log "${RED}  ✖ ${RESET} $*"; }
sep()  { log "${DIM}────────────────────────────────────────────────────────${RESET}"; }

die() {
  err "$1"
  log ""
  log "${DIM}Log saved: $LOG_FILE${RESET}"
  exit 1
}

# ── Argument parsing ───────────────────────────────────────────────────────────
DRY_RUN=false
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true; shift ;;
    --filter)
      [[ -z "${2:-}" ]] && die "--filter requires a value"
      FILTER="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--filter <name>]"
      echo ""
      echo "  --dry-run        Validate specs and print what would be pushed; no network calls"
      echo "  --filter <name>  Only push specs whose directory name contains <name>"
      echo ""
      echo "org, name, and version are read from each spec's spec.yaml metadata."
      exit 0 ;;
    *)
      die "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Banner ─────────────────────────────────────────────────────────────────────
log ""
log "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
log "${BOLD}║           SpecHub Batch Publisher                    ║${RESET}"
log "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
log ""
info "Root      : $ROOT_DIR"
info "Log file  : $LOG_FILE"
$DRY_RUN && warn "DRY RUN — no specs will be pushed"
[[ -n "$FILTER" ]] && info "Filter    : *${FILTER}*"
log ""

# ── Preflight ─────────────────────────────────────────────────────────────────
if ! command -v spechub &>/dev/null; then
  die "spechub CLI not found in PATH. Install it and try again."
fi

# ── Discover specs ─────────────────────────────────────────────────────────────
# bash 3 compatible (macOS ships bash 3.2)
SPEC_DIRS=()
while IFS= read -r d; do
  SPEC_DIRS+=("$d")
done < <(
  find "$ROOT_DIR" -maxdepth 2 -name "spec.yaml" \
    ! -path "*/publisher/*" \
    ! -path "*/.spechub/*" \
    -exec dirname {} \; | sort
)

if [[ ${#SPEC_DIRS[@]} -eq 0 ]]; then
  die "No spec.yaml files found under $ROOT_DIR"
fi

# Apply filter
if [[ -n "$FILTER" ]]; then
  FILTERED=()
  for d in "${SPEC_DIRS[@]}"; do
    [[ "$(basename "$d")" == *"$FILTER"* ]] && FILTERED+=("$d")
  done
  SPEC_DIRS=("${FILTERED[@]}")
  [[ ${#SPEC_DIRS[@]} -eq 0 ]] && die "No specs matched filter: $FILTER"
fi

info "Found ${#SPEC_DIRS[@]} spec(s) to process"
log ""

# ── Process each spec ──────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0
FAILED_SPECS=()

for SPEC_DIR in "${SPEC_DIRS[@]}"; do
  NAME="$(basename "$SPEC_DIR")"
  sep
  log "${BOLD}  ${NAME}${RESET}"
  log "  ${DIM}${SPEC_DIR}${RESET}"
  log ""

  # Validate spec.yaml is readable
  if [[ ! -f "$SPEC_DIR/spec.yaml" ]]; then
    warn "$NAME: spec.yaml disappeared — skipping"
    (( SKIP++ )) || true
    continue
  fi

  if $DRY_RUN; then
    if (cd "$SPEC_DIR" && spechub validate .) >> "$LOG_FILE" 2>&1; then
      ok "$NAME: validation passed (dry-run — push skipped)"
      (( PASS++ )) || true
    else
      err "$NAME: validation FAILED"
      (( FAIL++ )) || true
      FAILED_SPECS+=("$NAME")
    fi
    log ""
    continue
  fi

  # Real push — identity (org/name:version) comes from spec.yaml metadata
  PUSH_LOG="$LOG_DIR/${NAME}_${TIMESTAMP}.log"

  info "Validating ..."
  set +e
  (cd "$SPEC_DIR" && spechub validate .) > "$PUSH_LOG" 2>&1
  EXIT_CODE=$?
  set -e

  if [[ $EXIT_CODE -ne 0 ]]; then
    err "$NAME: validation FAILED — skipping push"
    while IFS= read -r line; do
      log "       ${DIM}${line}${RESET}"
    done < "$PUSH_LOG"
    (( FAIL++ )) || true
    FAILED_SPECS+=("$NAME")
    log ""
    continue
  fi

  ok "$NAME: validation passed"
  info "Pushing ..."

  set +e
  (cd "$SPEC_DIR" && spechub push . --registry http://localhost:4000) >> "$PUSH_LOG" 2>&1
  EXIT_CODE=$?
  set -e

  # Append per-spec log to main log
  cat "$PUSH_LOG" >> "$LOG_FILE"

  if [[ $EXIT_CODE -eq 0 ]]; then
    ok "$NAME: pushed successfully"
    grep -E "(Pushed|Digest|Changelog)" "$PUSH_LOG" | while read -r line; do
      log "       ${DIM}${line}${RESET}"
    done
    (( PASS++ )) || true
  else
    err "$NAME: push FAILED (exit $EXIT_CODE)"
    grep -iE "(error|failed|unauthorized|invalid|not found)" "$PUSH_LOG" | head -5 | while read -r line; do
      err "       ${line}"
    done
    info "Full output: $PUSH_LOG"
    (( FAIL++ )) || true
    FAILED_SPECS+=("$NAME")
  fi

  log ""
done

# ── Summary ────────────────────────────────────────────────────────────────────
sep
log ""
log "${BOLD}  Summary${RESET}"
log ""
ok "Passed : ${PASS}"
[[ $SKIP -gt 0 ]]  && warn "Skipped: ${SKIP}"
[[ $FAIL -gt 0 ]]  && err "Failed : ${FAIL}"

if [[ ${#FAILED_SPECS[@]} -gt 0 ]]; then
  log ""
  err "Failed specs:"
  for s in "${FAILED_SPECS[@]}"; do
    err "  • $s"
  done
fi

log ""
info "Full log: $LOG_FILE"
log ""

[[ $FAIL -gt 0 ]] && exit 1
exit 0
