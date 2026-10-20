# Browser stack availability on this VM, 2026-10-10 (20:10 to about 20:20 AEDT)

Host: Debian 13 (trixie) x86_64, kernel 6.12, user `box` (uid 1000), no sudo, 8 CPU, 16 GB RAM. Tried only user-level installs.

## Summary table

| component | status | how installed | CDP port 9222 listening | blocker |
|---|---|---|---|---|
| docker (browser-up.sh path) | NOT available | not installed | no | No docker, podman, buildah, nerdctl, skopeo, crane or proot. No `newuidmap`/`newgidmap` (so rootless docker/podman cannot map the /etc/subuid range `box:100000:65536`) and no root to install. `unshare -U` and `bwrap` work, so user namespaces are fine, but nothing user-level provides a container runtime. |
| CloakBrowser (stealth Chromium, free v146 binary) | RUNNING (non-docker) | `uv venv` + `uv pip install cloakbrowser aiohttp websockets geoip2 socksio` in `~/.local/share/ts-browser/venv`. Binary auto-downloaded by `python -m cloakbrowser install` (206 MB, Ed25519 + SHA-256 verified) to `~/.cloakbrowser/chromium-146.0.7680.177.5/`. | yes (127.0.0.1 only) | Free binary is v146. The latest v154 needs a free licence key via GitHub sign-in (`cloakbrowser login`). I did not do that sign-in; it is DT's call. |
| cloakserve (CDP multiplexer, what the docker image runs) | RUNNING | `bin/cloakserve` from the official repo saved as `~/.local/share/ts-browser/cloakserve.py` (reviewed: binds 127.0.0.1 outside a container). Launched by `~/.local/share/ts-browser/start-cloakserve.sh` on a private `Xvfb :99` (headed mode, same as the docker entrypoint). | yes | Does not survive a VM reboot (no systemd/cron/timer created). |
| agent-browser | INSTALLED, works | `npm i -g --prefix ~/.local agent-browser@0.39.0` gives `~/.local/bin/agent-browser` (an earlier unpinned install pulled 0.27.0; this record's pin is 0.39.0) | yes (it connects) | npm warns EBADENGINE: it declares node >=24, this box has node 22.23.2. It runs fine on 22 in my tests. |
| browser-mcp.sh (agent-browser MCP) | works | no new install. Script run from the /tmp copy. | yes | MCP `initialize` and `tools/list` returned over stdio against the 9222 sidecar. |
| Scrapling | INSTALLED, works | `uv pip install 'scrapling[fetchers]'` in the same venv (0.4.15). Symlinks `~/.local/bin/scrapling`, `scrapling-mcp`. | n/a | The base `scrapling` alone lacks `click` and `curl_cffi`. The `[fetchers]` extra is needed. Browser-based fetchers need `scrapling install`; I did not run it, since CloakBrowser covers that. |
| Firecrawl | NOT set up (by design) | not installed. Routes exist: `firecrawl-mcp` 3.29.1 (npm, bin `firecrawl-mcp`, run via `npx`), `firecrawl` 4.46.0 (JS SDK for the hosted API). | n/a | Hosted API needs an API key and billing, which I did not set up. A self-host needs docker (unavailable). `npx` is present (prerequisite met). |
| rustwright-mcp | not installed | not investigated (optional in the doctor) | n/a | optional |

## main vs PR #3 findings (read-only)

- `scripts/browser-up.sh`, `browser-mcp.sh`, `browser-doctor.sh` exist on `main` (`git ls-tree`). PR #3 `e1d9eb1 feat: browser stack bootstrap (#3)` is an ancestor of `main`, so it is merged. `config/browser/mcp.example.json`, `playbooks/_schema.example.json`, `docs/browser-stack/PLAN.md` and `ROUTING.md` are also on main. `feat/browser-stack` still exists as a branch and on origin.
- `$WORKSPACE/thunderstone-starter` was on `main` with a clean tree when I looked (`git status --short` is empty). I did not check out, switch, edit or write there. I ran everything from `git archive main | tar -x -C /tmp/ts-browser`, not a `git worktree`, so there is nothing to prune. The /tmp copy can be deleted with `rm -rf /tmp/ts-browser`.
- browser-up.sh runs `docker run -d --name cloakbrowser -p 127.0.0.1:9222:9222 -v .state/browser/profiles:/profiles cloakhq/cloakbrowser cloakserve --headless=false --idle-timeout=600` and hard-requires `docker`. Its non-docker equivalent is what I started (same `cloakserve --headless=false --idle-timeout=600`).

## browser-doctor.sh output (from the /tmp copy of main)

Before any install, exit 1:
miss docker / miss cdp / miss agent-browser / miss scrapling / ok npx / miss rustwright-mcp

After the user-level installs, exit 1:
miss docker / ok cdp / ok agent-browser / ok scrapling / ok npx / miss rustwright-mcp

The doctor still exits 1 only because `docker` is classed as a core check. The path actually works without docker. Smallest fix, if DT wants it (a repo change, not made here): downgrade the docker check to optional, or treat docker or a live CDP endpoint as satisfying it.

## Smoke test (example.com only; marketindex.com.au not touched)

- `curl -s http://127.0.0.1:9222/json/version` returned `Chrome/146.0.7680.177`, with a webSocketDebuggerUrl rewritten through cloakserve.
- Playwright `connect_over_cdp("http://127.0.0.1:9222")`, goto https://example.com: title `Example Domain`, URL `https://example.com/`, `navigator.webdriver` = False (exit 0). The script is `~/.local/share/ts-browser/smoke.py`.
- `agent-browser --cdp http://127.0.0.1:9222 open https://example.com` printed "Example Domain"; `get title` returned the same.
- `scripts/browser-mcp.sh` (via agent-browser) answered MCP `initialize` and `tools/list` (tool profiles core, network, state, tabs).
- Scrapling `Fetcher.get("https://example.com")` returned HTTP 200.

## Commands tried that failed (exact errors)

- `command -v docker podman buildah nerdctl skopeo crane proot newuidmap newgidmap`: none found. Only `bwrap`, `unshare`, `uv`, `node`, `npm` and `google-chrome` (154.0.8037.97) are present.
- `scripts/browser-up.sh` was NOT run (it would only print "docker required").
- `scrapling --help` after a plain `uv pip install scrapling`: `ModuleNotFoundError: No module named 'click'`; then `No module named 'curl_cffi'`. Fixed by installing `scrapling[fetchers]`.
- `cloakserve` logs repeated Chrome noise (dbus "Failed to connect to the bus", GPU "kTransientFailure"). It is harmless: no session bus here and no GPU, and CDP works.
- `npm i -g agent-browser` pulled 0.27.0 while `npm view` said latest 0.39.0. Pinning `@0.39.0` fixed it, with an EBADENGINE warning (node >=24 declared).
- `cloakbrowser info` notes: Windows, Office and Mac fonts missing (affects stealth personas only) and GeoIP DB not downloaded (optional).

## Install locations (to undo)

- `~/.local/share/ts-browser/`: venv (cloakbrowser, playwright, aiohttp, websockets, geoip2, socksio, scrapling[fetchers], patchright, curl-cffi), `cloakserve.py`, `start-cloakserve.sh`, `stop-cloakserve.sh`, `smoke.py`, `run/` (pid and log files), `profiles/` (empty). About 371 MB.
- `~/.cloakbrowser/chromium-146.0.7680.177.5/` and its cache: about 701 MB, the stealth Chromium binary.
- `~/.local/lib/node_modules/agent-browser` (0.39.0), `~/.local/bin/agent-browser`. About 115 MB.
- Symlinks `~/.local/bin/scrapling` and `~/.local/bin/scrapling-mcp` point into the venv.
- `/tmp/ts-browser/` (git archive of `main`) and `/tmp/cloak-readme.md` are scratch.
- Undo everything: `~/.local/share/ts-browser/stop-cloakserve.sh; rm -rf ~/.local/share/ts-browser ~/.cloakbrowser /tmp/ts-browser /tmp/cloak-readme.md; rm -f ~/.local/bin/scrapling ~/.local/bin/scrapling-mcp; npm rm -g --prefix ~/.local agent-browser`
- No system packages, no sudo, no edits to `$WORKSPACE/thunderstone-starter`, and no cron, timer or routine.

## Still running

Left running as the intended lightweight sidecar. Memory is about 19 MB for Xvfb, 53 MB for cloakserve, plus Chrome (spawned on demand and idle-killed after 600 s).
- Xvfb :99 PID 240286, cloakserve PID 240299 (Chrome child PID 240310 at the time). 9222 is bound to 127.0.0.1 only; Chrome's internal debug port 5100 is also loopback.
- Start: `~/.local/share/ts-browser/start-cloakserve.sh`. Stop: `~/.local/share/ts-browser/stop-cloakserve.sh` (kills the PIDs in `run/*.pid`). Logs: `~/.local/share/ts-browser/run/cloakserve.log`.
- Does not auto-start after a reboot.

## Not done / needs DT

- Latest CloakBrowser build (v154) requires a free GitHub sign-in key (`cloakbrowser login`); not done.
- The doctor's docker core check stays red unless the repo changes (see above).
- No browser-up.sh equivalent for non-docker exists in the repo. A small `scripts/browser-up-local.sh` PR would capture the start script; not created (no git writes).

Commit/push/PR: not performed.
