<!-- lean-ctx-owned: PROJECT-LEAN-CTX.md v1 -->
<!-- lean-ctx-rules -->
<!-- version: 9 -->

lean-ctx shadow mode: native read/search/shell calls auto-route to ctx_* — no tool-mapping needed.
File editing → native Edit/StrReplace (lean-ctx only handles reads); if denied, use ctx_patch.
Exclusive tools (no native trigger): ctx_compose (understand code, call first), ctx_search(action=symbol) (exact symbol), ctx_search(action=semantic) (by meaning), ctx_callgraph (callers), ctx_knowledge / ctx_session (memory).
<!-- lean-ctx-solution -->
SOLUTION EFFICIENCY: stop at first level that applies:
skip (YAGNI) → reuse codebase → stdlib → native platform → installed dep → one-line → minimum code.
Never skip: validation, security, error handling.
<!-- /lean-ctx-solution -->
Clan reports stay in full sentences. A generated token budget is not in force.
Caveman tone is opt-in. See AGENTS.md.
`lean-ctx setup` may rewrite this file. If it restores a token budget, delete that block again.
<!-- /lean-ctx-rules -->
