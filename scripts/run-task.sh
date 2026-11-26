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
  # Session logs go to <tmpdir>/cursor-agent-logs-<uid>. The CLI-only profile
  # switches HOME/XDG_* for the agent but not TMPDIR, so the log dir does not
  # move with HOME (checked on the VM 27 Nov: the profile run logged under
  # /tmp/cursor-agent-logs-<uid>, nothing under the profile home). Search the
  # TMPDIR and /tmp forms; CURSOR_AGENT_LOG_DIR overrides both.
  local uid logdirs=() d
  uid="$(id -u)"
  if [[ -n "${CURSOR_AGENT_LOG_DIR:-}" ]]; then
    logdirs=("$CURSOR_AGENT_LOG_DIR")
  else
    logdirs=("${TMPDIR:-/tmp}/cursor-agent-logs-$uid")
    [[ "${TMPDIR:-/tmp}" == "/tmp" ]] || logdirs+=("/tmp/cursor-agent-logs-$uid")
  fi
  local latest=""
  # Only attribute a session log written during this run (newest by mtime).
  # No stamp or no new log -> leave token columns blank rather than guess.
  # mtime >= stamp (not find -newer): coarse fs timestamps can tie on fast runs.
  if [[ -n "$stamp" && -e "$stamp" ]]; then
    local stamp_t
    stamp_t="$(find "$stamp" -maxdepth 0 -printf '%T@' 2>/dev/null || true)"
    if [[ -n "$stamp_t" ]]; then
      latest="$(for d in "${logdirs[@]}"; do
          [[ -d "$d" ]] && find "$d" -maxdepth 1 -type f -name 'session-*.log' -printf '%T@ %p\n' 2>/dev/null
        done | awk -v s="$stamp_t" '$1 >= s' | sort -n | tail -n 1 | cut -d' ' -f2-)"
    fi
  fi
  if [[ -n "$latest" && -r "$latest" ]]; then
    src="$latest"
    # Take the last usage tuple in the log (final counts). Accept key=N, ...
    # and the JSON form the CLI writes today ("input_tokens":"N",...).
    local line
    line="$(grep -oE 'input_tokens=[0-9]+, output_tokens=[0-9]+, cache_read_tokens=[0-9]+, cache_write_tokens=[0-9]+(, duration_ms=[0-9]+)?|("duration_ms":"[0-9]+",[^{}]*)?"input_tokens":"[0-9]+","output_tokens":"[0-9]+","cache_read_tokens":"[0-9]+","cache_write_tokens":"[0-9]+"' "$latest" 2>/dev/null | tail -n 1 || true)"
    if [[ -n "$line" ]]; then
      input="$(sed -n 's/.*input_tokens"\{0,1\}[=:]"\{0,1\}\([0-9]*\).*/\1/p' <<<"$line")"
      output="$(sed -n 's/.*output_tokens"\{0,1\}[=:]"\{0,1\}\([0-9]*\).*/\1/p' <<<"$line")"
      cache_r="$(sed -n 's/.*cache_read_tokens"\{0,1\}[=:]"\{0,1\}\([0-9]*\).*/\1/p' <<<"$line")"
      cache_w="$(sed -n 's/.*cache_write_tokens"\{0,1\}[=:]"\{0,1\}\([0-9]*\).*/\1/p' <<<"$line")"
      duration_ms="$(sed -n 's/.*duration_ms"\{0,1\}[=:]"\{0,1\}\([0-9]*\).*/\1/p' <<<"$line")"
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
#
# CLI-only profile (t12s1 job4). Persistent HOME defaults to the ops tree's
# sibling token-optimizer/state/cursor-cli-home (not tmp/dist/build/.cache);
# TS_CLI_HOME overrides. No ops root and no TS_CLI_HOME -> profile off.
# Sets HOME + CURSOR_CONFIG_DIR + CURSOR_DATA_DIR + XDG_* for the agent only
# (does not export HOME for the rest of this script). Empty user mcp.json and
# allowlisted skills are already in that profile. This does not disable
# account/1p plugins: agent still loaded 350 plugin skills / 358 rules
# (428.6 s). Token win vs 27,227 baseline was -20.7% (21,593 in), mostly
# from dropping user MCP. No --no-plugins flag exists; cli-config plugin
# flags are stripped by schema. TS_CLI_PROFILE=0 (or a missing profile dir)
# keeps the plain launch below. Inherit CURSOR_API_KEY if the environment
# already has it (do not print it).
_ts_cli_home="${TS_CLI_HOME:-}"
if [[ -z "$_ts_cli_home" && -n "$ops_root" ]]; then
  _ts_cli_home="$(dirname "$ops_root")/token-optimizer/state/cursor-cli-home"
fi
_ts_cli_env=()
if [[ "${TS_CLI_PROFILE:-1}" != "0" && -n "$_ts_cli_home" && -d "$_ts_cli_home/.cursor" ]]; then
  _ts_cli_env=(
    "HOME=$_ts_cli_home"
    "CURSOR_CONFIG_DIR=$_ts_cli_home/.cursor"
    "CURSOR_DATA_DIR=$_ts_cli_home/.cursor"
    "XDG_CONFIG_HOME=$_ts_cli_home/.config"
    "XDG_DATA_HOME=$_ts_cli_home/.local/share"
    "XDG_STATE_HOME=$_ts_cli_home/.local/state"
    "XDG_CACHE_HOME=$_ts_cli_home/.cache"
  )
fi
# Empty profile -> exact pre-profile launch (no env wrapper); ${#arr[@]} is
# safe under set -u for an empty array.
_ts_launch=(agent)
if (( ${#_ts_cli_env[@]} > 0 )); then
  _ts_launch=(env "${_ts_cli_env[@]}" agent)
fi
# Auth preflight under the same env the job will use (exit 77, no retry).
# `agent status` exits 0 even when logged out; parse the JSON instead.
_ts_status="$(timeout 20 "${_ts_launch[@]}" status --format json 2>/dev/null || true)"
if ! grep -qE '"isAuthenticated"[[:space:]]*:[[:space:]]*true' <<<"$_ts_status"; then
  echo "AUTH_MISSING: run 'agent login' (DT); no retry" >&2
  [[ -z "$ts_stamp" ]] || rm -f "$ts_stamp" || true
  exit 77
fi
started_epoch="$(date +%s)"
set +e
"${_ts_launch[@]}" -p --trust --force --model "${TS_MODEL:-composer-2.5}" "Read AGENTS.md and the task brief at $brief. Execute only its scope. Do not spawn another Cursor CLI. Validate and save a concise report under workspace/reports. Do not push, deploy or send messages."
ec=$?
set -e
_ts_ledger_append "$ec" "$started_epoch" "$ts_stamp" || true
[[ -z "$ts_stamp" ]] || rm -f "$ts_stamp" || true
exit "$ec"
