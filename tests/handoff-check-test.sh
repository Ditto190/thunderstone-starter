#!/usr/bin/env bash
# handoff.sh --check unit + regression (COMMS SPEC 2026-11-02)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
H=scripts/handoff.sh
export HANDOFF_DIR="${TMPDIR:-/tmp}/handoff-test-$$"
mkdir -p "$HANDOFF_DIR"
trap 'rm -rf "$HANDOFF_DIR"' EXIT
PASS=0; FAIL=0
assert_exit() {
  local want=$1 name=$2; shift 2
  set +e
  out=$("$@" 2>&1)
  ec=$?
  set -e
  if [[ $ec -eq $want ]]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "FAIL $name: want exit $want got $ec; out=$out" >&2
  fi
}

# --- unit: pass ---
GOOD='{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"ro","return":"path+<=5"}'
assert_exit 0 pass-json "$H" --check "$GOOD"
assert_exit 0 pass-json-pri "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"stage","return":"path+3","pri":"P2"}'
assert_exit 0 pass-dt "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"dt:\"Yes: do it\"@2026-11-02T17:38+11","return":"path+<=5"}'
assert_exit 0 pass-legacy "$H" --check $'ASK: short ask\nIN: /tmp/x'
# FILE mode
printf '%s\nbody\n' "$GOOD" >"$HANDOFF_DIR/ok.md"
assert_exit 0 pass-file "$H" --check "$HANDOFF_DIR/ok.md"

# --- unit: fail ---
assert_exit 1 fail-missing "$H" --check '{"goal":"g","owner":"o"}'
assert_exit 1 fail-order "$H" --check '{"owner":"o","goal":"g","success":"s","evidence_path":"/p","approval":"ro","return":"path+<=5"}'
assert_exit 1 fail-multiline "$H" --check $'{"goal":"g"\n,"owner":"o","success":"s","evidence_path":"/p","approval":"ro","return":"path+<=5"}'
assert_exit 1 fail-approval "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"maybe","return":"path+<=5"}'
assert_exit 1 fail-dt-shape "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"dt:Yes without quotes@2026-11-02","return":"path+<=5"}'
assert_exit 1 fail-dt-short-time "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"dt:\"Yes\"@1","return":"path+<=5"}'
assert_exit 1 fail-dt-trailing "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"dt:\"Yes\"@2026-11-02T17:38+11 trailing","return":"path+<=5"}'
assert_exit 1 fail-return-99 "$H" --check '{"goal":"g","owner":"o","success":"s","evidence_path":"/p","approval":"ro","return":"path+99"}'
assert_exit 1 fail-not-json "$H" --check '{not json'
LONG=$(python3 -c 'print("{\"goal\":\"g\",\"owner\":\"o\",\"success\":\"s\",\"evidence_path\":\"/p\",\"approval\":\"ro\",\"return\":\"path+<=5\",\"body\":\"" + "x"*280 + "\"}")')
assert_exit 1 fail-over300 "$H" --check "$LONG"
assert_exit 1 fail-legacy-long "$H" --check "$(python3 -c 'print("ASK: "+"y"*310)')"

# --- regression: 3 fixtures must pass --check ---
for i in 1 2 3; do
  assert_exit 0 "regress-m$i" "$H" --check "tests/fixtures/comms-spec/m$i.header.json"
done
# --- token / size guard: current <= baseline (tiktoken when available; char fallback always) ---
# TOKEN_PY overrides the interpreter (default python3). Never hard-code a venv path.
TOKEN_PY="${TOKEN_PY:-python3}"
run_size_guard() {
  # Args: fixture_dir baseline_json
  # Exit 0 ok; 1 growth; 2 interpreter/baseline error
  local fixdir=$1 basejson=$2
  FIXDIR="$fixdir" BASEJSON="$basejson" "$TOKEN_PY" - <<'PY'
import json, os, pathlib, sys
fixdir = pathlib.Path(os.environ["FIXDIR"])
base = json.loads(pathlib.Path(os.environ["BASEJSON"]).read_text())
# Char / byte fallback (UTF-8 byte length of header line) — always runs; FAILS on growth.
cur_chars = 0
for i in range(1, 4):
    line = (fixdir / f"m{i}.header.json").read_text().rstrip("\n")
    n = len(line.encode("utf-8"))
    cur_chars += n
    b = base[f"m{i}"]["fallback_chars"]
    if n > b:
        print(f"m{i} fallback_chars {n} > baseline {b}")
        sys.exit(1)
tb = base["total"]["fallback_chars"]
if cur_chars > tb:
    print(f"total fallback_chars {cur_chars} > baseline {tb}")
    sys.exit(1)
print(f"fallback-guard ok total_chars={cur_chars} baseline={tb}")

# Optional tiktoken path when the module is importable.
try:
    import tiktoken
except ImportError:
    print("tiktoken absent; fallback-only")
    sys.exit(0)
enc = tiktoken.get_encoding("cl100k_base")
cur_tok = 0
for i in range(1, 4):
    line = (fixdir / f"m{i}.header.json").read_text().rstrip("\n")
    tok = len(enc.encode(line))
    cur_tok += tok
    b = base[f"m{i}"]["tokens_cl100k"]
    if tok > b:
        print(f"m{i} tokens {tok} > baseline {b}")
        sys.exit(1)
bt = base["total"]["tokens_cl100k"]
if cur_tok > bt:
    print(f"total tokens {cur_tok} > baseline {bt}")
    sys.exit(1)
print(f"token-guard ok total={cur_tok} baseline={bt}")
PY
}

set +e
tok_out=$(run_size_guard "tests/fixtures/comms-spec" "tests/fixtures/comms-spec/cl100k-baseline.json" 2>&1)
tec=$?
set -e
if [[ $tec -eq 0 ]]; then PASS=$((PASS+1)); echo "$tok_out"
elif [[ $tec -eq 2 ]]; then FAIL=$((FAIL+1)); echo "FAIL size-guard setup: $tok_out" >&2
else FAIL=$((FAIL+1)); echo "FAIL size-guard: $tok_out" >&2
fi

# Prove fallback FAILS on growth: temp copy with one header grown by 1 byte, same baseline.
GROW="$HANDOFF_DIR/grown-fixtures"
mkdir -p "$GROW"
cp tests/fixtures/comms-spec/m1.header.json tests/fixtures/comms-spec/m2.header.json \
  tests/fixtures/comms-spec/m3.header.json "$GROW/"
FIXDIR="$GROW" "$TOKEN_PY" - <<'PY'
import json, os, pathlib
p = pathlib.Path(os.environ["FIXDIR"]) / "m1.header.json"
o = json.loads(p.read_text())
o["goal"] = o["goal"] + "X"
order = ["goal", "owner", "success", "evidence_path", "approval", "return", "pri", "due", "body"]
ordered = {k: o[k] for k in order if k in o}
p.write_text(json.dumps(ordered, separators=(",", ":"), ensure_ascii=False) + "\n")
print("grown m1 chars", len(p.read_text().rstrip("\n").encode()))
PY
set +e
grow_out=$(run_size_guard "$GROW" "tests/fixtures/comms-spec/cl100k-baseline.json" 2>&1)
gec=$?
set -e
if [[ $gec -eq 1 ]]; then PASS=$((PASS+1)); echo "fallback-growth-fail ok: $grow_out"
else FAIL=$((FAIL+1)); echo "FAIL fallback-growth (want exit 1 got $gec): $grow_out" >&2
fi

echo "handoff-check-test: pass=$PASS fail=$FAIL"
[[ $FAIL -eq 0 ]]
