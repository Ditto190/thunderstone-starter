#!/usr/bin/env bash
# Remote/cloud agent helpers. Never prints token plaintext.
set -euo pipefail

ROOT="${THUNDERSTONE_ROOT:-/workspace/thunderstone}"
NAME_RE='^[a-z0-9][a-z0-9._-]{0,63}$'
usage() {
  echo "usage: remote-agents.sh {status|cli <brief>|add-client <name>|revoke-client <name>}" >&2
  exit 64
}

http_code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$1" || echo 000
}

cmd_status() {
  local code
  code="$(http_code http://127.0.0.1:3847/health)"
  if [[ "${code}" == "401" || "${code}" == "200" ]]; then
    echo "bridge: up (127.0.0.1:3847 health ${code})"
  else
    echo "bridge: down (health ${code})"
  fi
  if ~/.local/bin/ts funnel status 2>/dev/null | grep -q '/mcp'; then
    echo "funnel: on https://grok-bot-vm-347906125.tail6c4b90.ts.net/mcp"
  else
    echo "funnel: off or status unreadable"
  fi
  if tmux has-session -t '=dc' 2>/dev/null; then echo "dc: tmux up"; else echo "dc: tmux down"; fi
  if tmux has-session -t '=tailscaled' 2>/dev/null; then echo "tailscaled: tmux up"; else echo "tailscaled: tmux down"; fi
  if tmux has-session -t '=cursor-cloud' 2>/dev/null; then echo "cursor-cloud: tmux up"; else echo "cursor-cloud: tmux absent"; fi
}

cmd_cli() {
  local brief="${1:-}"
  [[ -n "${brief}" ]] || usage
  exec "${ROOT}/scripts/run-task.sh" "${brief}"
}

python_token() {
  python3 - "$@" <<'PY'
import hashlib, json, os, secrets, sys, time
op, name = sys.argv[1], sys.argv[2]
token_dir = os.path.expanduser("~/.config/thunderstone-bridge")
plain_dir = os.path.join(token_dir, "tokens")
tokens_path = os.path.join(token_dir, "tokens.json")
os.makedirs(plain_dir, mode=0o700, exist_ok=True)
os.chmod(token_dir, 0o700)
os.chmod(plain_dir, 0o700)
store = {}
if os.path.exists(tokens_path):
    with open(tokens_path, "r", encoding="utf-8") as f:
        store = json.load(f)
plain_path = os.path.join(plain_dir, name + ".token")
if op == "add":
    token = secrets.token_urlsafe(32)
    store[name] = {"hash": hashlib.sha256(token.encode()).hexdigest(), "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    fd = os.open(plain_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(token + "\n")
    os.chmod(plain_path, 0o600)
elif op == "revoke":
    store.pop(name, None)
    if os.path.exists(plain_path):
        os.remove(plain_path)
else:
    sys.exit(2)
tmp = tokens_path + ".tmp"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(store, f, indent=2)
    f.write("\n")
os.chmod(tmp, 0o600)
os.replace(tmp, tokens_path)
os.chmod(tokens_path, 0o600)
print(op + " " + name)
PY
}

cmd_add() {
  local name="${1:-}"
  [[ "${name}" =~ ${NAME_RE} ]] || { echo "bad client name" >&2; exit 1; }
  python_token add "${name}"
  echo "credential hash written; bridge reloads tokens per request (no process restart)"
}

cmd_revoke() {
  local name="${1:-}"
  [[ "${name}" =~ ${NAME_RE} ]] || { echo "bad client name" >&2; exit 1; }
  python_token revoke "${name}"
  echo "credential revoked; bridge reloads tokens per request (no process restart)"
}

main() {
  local cmd="${1:-}"
  shift || true
  case "${cmd}" in
    status) cmd_status ;;
    cli) cmd_cli "${1:-}" ;;
    add-client) cmd_add "${1:-}" ;;
    revoke-client) cmd_revoke "${1:-}" ;;
    *) usage ;;
  esac
}

main "$@"
