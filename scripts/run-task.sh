#!/usr/bin/env bash
set -euo pipefail
# BASH_ENV (vm-ops-env on the VM) re-prepends PATH in every child bash the agent
# starts, which breaks hermetic tests and stubs. Never pass it to the agent.
unset BASH_ENV ENV
export PATH="$HOME/.local/bin:$PATH"
brief="${1:?Usage: run-task.sh <brief.md>}"
[[ -r "$brief" ]] || { echo "Brief not readable"; exit 1; }
# Ops tree is a sibling of this repo. pwd -P follows the thunderstone/scripts symlink.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ops_root=""
if [[ -n "${THUNDERSTONE_OPERATIONAL_ROOT:-}" ]]; then
  ops_root="$THUNDERSTONE_OPERATIONAL_ROOT"
elif [[ -d "$script_dir/../../thunderstone" ]]; then
  ops_root="$(cd "$script_dir/../../thunderstone" && pwd)"
else
  echo "warn: ops root unresolved; skipping usage-limit guard" >&2
fi
if [[ -n "$ops_root" ]]; then
  L="$ops_root/state/cloud-agent-ledger.md"
  D=$(TZ=Australia/Sydney date +%F)
  # Block only when today's row has a status field (last column) starting with
  # "usage-limit"; free-text mentions elsewhere in a row must not block.
  if [[ -r "$L" ]] && awk -F'|' -v d="$D" '
    { n=NF; while (n > 2 && $n ~ /^[[:space:]]*$/) n--; if (n <= 2) next
      date=$2; st=$n
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", date); gsub(/^[[:space:]]+/, "", st)
      if (date == d && tolower(st) ~ /^usage-limit/) { found=1; exit } }
    END { exit !found }' "$L"; then echo "blocked: usage-limit recorded today (no retry)"; exit 75; fi
fi
command -v agent >/dev/null || { echo "Install Cursor CLI first"; exit 1; }

# Per-job token ledger (TS_LEDGER; default ops_root/state/pr-autopipeline/ledger.tsv).
# Do not fail the job if the ledger write fails. Preserve the agent exit code.
_ts_ledger_append() {
  local ec="$1" started_epoch="$2" stamp="${3:-}"
  local ledger="${TS_LEDGER:-}"
  if [[ -z "$ledger" && -n "$ops_root" ]]; then
    ledger="$ops_root/state/pr-autopipeline/ledger.tsv"
  fi
  [[ -n "$ledger" ]] || return 0
  [[ -f "$ledger" ]] || return 0
  local ended_epoch wall duration_ms="" input="" output="" cache_r="" cache_w="" src=""
  ended_epoch="$(date +%s)"
  wall=$(( ended_epoch - started_epoch ))
  local logdir="${CURSOR_AGENT_LOG_DIR:-/tmp/cursor-agent-logs-$(id -u)}"
  local latest=""
  # Only attribute a session log written during this run (newest by mtime).
  # No stamp or no new log -> leave token columns blank rather than guess.
  # mtime >= stamp (not find -newer): coarse fs timestamps can tie on fast runs.
  if [[ -d "$logdir" && -n "$stamp" && -e "$stamp" ]]; then
    local stamp_t
    stamp_t="$(find "$stamp" -maxdepth 0 -printf '%T@' 2>/dev/null || true)"
    if [[ -n "$stamp_t" ]]; then
      latest="$(find "$logdir" -maxdepth 1 -type f -name 'session-*.log' -printf '%T@ %p\n' 2>/dev/null \
        | awk -v s="$stamp_t" '$1 >= s' | sort -n | tail -n 1 | cut -d' ' -f2-)"
    fi
  fi
  if [[ -n "$latest" && -r "$latest" ]]; then
    src="$latest"
    # Take the last usage tuple in the log (final counts).
    local line
    line="$(grep -oE 'input_tokens=[0-9]+, output_tokens=[0-9]+, cache_read_tokens=[0-9]+, cache_write_tokens=[0-9]+(, duration_ms=[0-9]+)?' "$latest" 2>/dev/null | tail -n 1 || true)"
    if [[ -n "$line" ]]; then
      input="$(sed -n 's/.*input_tokens=\([0-9]*\).*/\1/p' <<<"$line")"
      output="$(sed -n 's/.*output_tokens=\([0-9]*\).*/\1/p' <<<"$line")"
      cache_r="$(sed -n 's/.*cache_read_tokens=\([0-9]*\).*/\1/p' <<<"$line")"
      cache_w="$(sed -n 's/.*cache_write_tokens=\([0-9]*\).*/\1/p' <<<"$line")"
      duration_ms="$(sed -n 's/.*duration_ms=\([0-9]*\).*/\1/p' <<<"$line")"
    fi
  fi
  local ts job brief_s cli model tier rung cwd_s trigger notes
  ts="$(TZ=Australia/Sydney date '+%Y-%m-%d %H:%M:%S %z')"
  job="${TS_JOB_ID:-$(TZ=Australia/Sydney date +%Y%m%dT%H%M%S)}"
  brief_s="${brief//$'\t'/ }"
  cli="cursor-agent"
  model="${TS_MODEL:-composer-2.5}"
  case "$model" in
    composer-2.5*) tier="T1" ;;
    grok-4.7-low*|grok-4.7-medium*) tier="T2" ;;
    grok-4.7-high*) tier="T3" ;;
    *) tier="?" ;;
  esac
  rung="${TS_ACTOR_RUNG:-}"
  cwd_s="$(pwd)"
  trigger="${TS_TRIGGER:-run-task.sh}"
  notes="${TS_LEDGER_NOTES:-}"
  # Sanitize TSV fields (tabs/newlines).
  local f fields
  fields=("$ts" "$job" "$brief_s" "$cli" "$model" "$tier" "$rung" "$ec" "$wall" "$duration_ms" "$input" "$output" "$cache_r" "$cache_w" "$cwd_s" "$trigger" "$src" "$notes")
  local row=""
  for f in "${fields[@]}"; do
    f="${f//$'\t'/ }"
    f="${f//$'\n'/ }"
    row+="${row:+	}$f"
  done
  printf '%s\n' "$row" >> "$ledger" || echo "warn: ledger append failed: $ledger" >&2
}

# Unique start marker for session-log attribution; never blocks the launch.
ts_stamp="$(mktemp "${TMPDIR:-/tmp}/ts-run-task-start.XXXXXX" 2>/dev/null || true)"
# DT standing law: VM agents have full auto-permission; keep --trust --force.
started_epoch="$(date +%s)"
set +e
agent -p --trust --force --model "${TS_MODEL:-composer-2.5}" "Read AGENTS.md and the task brief at $brief. Execute only its scope. Do not spawn another Cursor CLI. Validate and save a concise report under workspace/reports. Do not push, deploy or send messages."
ec=$?
set -e
_ts_ledger_append "$ec" "$started_epoch" "$ts_stamp" || true
[[ -z "$ts_stamp" ]] || rm -f "$ts_stamp" || true
exit "$ec"
