#!/usr/bin/env bash
# Verify Perplexity MCP prerequisites without printing secrets.
set -uo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."; fail=0
say() { printf '%-5s %s\n' "$1" "$2"; }
if [ -f .env ]; then
  perm=$(stat -c %a .env 2>/dev/null || stat -f %Lp .env)
  [ "$perm" = 600 ] && say ok ".env mode 600" || { say warn ".env mode $perm (run: chmod 600 .env)"; }
  git check-ignore -q .env && say ok ".env gitignored" || { say FAIL ".env not gitignored"; fail=1; }
fi
key=$(node scripts/env-run.mjs node -e 'process.stdout.write(process.env.PERPLEXITY_API_KEY||"")' 2>/dev/null)
[ -n "$key" ] && say ok "PERPLEXITY_API_KEY set (${#key} chars)" || { say FAIL "PERPLEXITY_API_KEY missing"; fail=1; }
if git grep -qE 'pplx-[A-Za-z0-9]{20,}' -- . ':!*.example' 2>/dev/null; then say FAIL "key-like string committed"; fail=1; else say ok "no committed pplx- keys"; fi
command -v npx >/dev/null && say ok "npx present" || { say FAIL "npx missing (scripts/ensure-node.sh)"; fail=1; }
code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 https://www.perplexity.ai/rest/computer/mcp)
case "$code" in 401|403|405|406|400) say ok "Computer MCP reachable (HTTP $code before OAuth)";; *) say warn "Computer MCP HTTP $code (check egress allowlist)";; esac
exit "$fail"
