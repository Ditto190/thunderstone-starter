# Environment variables and secret managers

Thunderstone agents run in several places (Cursor Cloud, Grok VM + My Machines worker, Grok Bots). **Key names** are shared; **values** live in a secret manager and/or local files—never in git or Drive.

## Loading order

`node scripts/env-run.mjs <command>` merges configuration in this order (first wins per key):

1. **Injected environment** (Cursor dashboard secrets, systemd, your shell)
2. **Secret manager** (Infisical or Doppler when enabled)
3. `/run/secrets/thunderstone.env` (optional mount)
4. `~/.config/thunderstone/env` (machine-wide on the Grok computer)
5. `.env.local` in the repo checkout (per-project overrides)
6. `.env.defaults` in git (non-secret defaults)

Nothing prints secret values. Use `node scripts/env-doctor.mjs` to see **set / missing** for the current surface.

Registry of keys: `config/env.registry.json`.

## Surfaces

| Surface | Set `THUNDERSTONE_SURFACE` | Where to put secrets |
|--------|----------------------------|----------------------|
| Grok VM / worker | `vm_worker` (default for doctor) | Infisical/Doppler token on VM + `~/.config/thunderstone/env` |
| Cursor Cloud agent | `cloud` | Cursor Environment secrets **and** same keys in Infisical/Doppler if workers need them |
| Local only | `local` | `.env.local` |

Cursor **dashboard** secrets apply to managed Cloud Agents. **My Machines** workers use the Grok VM environment (files + Infisical/Doppler), not the dashboard copy.

## Infisical

[Infisical](https://infisical.com) is the primary recommended manager (open-source, self-host or cloud).

1. Create a project and environments (`dev`, `staging`, `prod`).
2. Add secrets using the **same names** as `.env.example` / `config/env.registry.json`.
3. Create a **service token** (or machine identity) scoped to that project/environment.
4. Install the [Infisical CLI](https://infisical.com/docs/cli/overview).

On the Grok VM (or in Cursor build/runtime secrets for cloud):

```bash
# ~/.config/thunderstone/env (never commit)
THUNDERSTONE_SECRETS_BACKEND=infisical
INFISICAL_TOKEN=st.xxx
INFISICAL_PROJECT_ID=your-project-id
INFISICAL_ENV=dev
```

Run tasks as usual:

```bash
node scripts/env-run.mjs bash scripts/run-task.sh workspace/briefs/TASK-001.md
```

`auto` mode: if `THUNDERSTONE_SECRETS_BACKEND=auto` and `INFISICAL_TOKEN` is set with the CLI on PATH, Infisical is used before Doppler.

## Doppler

[Doppler](https://www.doppler.com) is a common hosted alternative with a similar CLI workflow.

1. Create a project and config (e.g. `dev`).
2. Store secrets with the same key names as the registry.
3. Create a **service token** for the VM or CI.
4. Install the [Doppler CLI](https://docs.doppler.com/docs/install-cli).

```bash
# ~/.config/thunderstone/env
THUNDERSTONE_SECRETS_BACKEND=doppler
DOPPLER_TOKEN=dp.st.xxx
DOPPLER_PROJECT=thunderstone
DOPPLER_CONFIG=dev
```

With `THUNDERSTONE_SECRETS_BACKEND=auto`, Doppler is used when `DOPPLER_TOKEN` is set and Infisical is not selected.

## Local files without a manager

Leave `THUNDERSTONE_SECRETS_BACKEND` unset or `off`. Copy `.env.example` to `.env.local` and/or maintain `~/.config/thunderstone/env`.

## Cursor Cloud checklist

1. Add **runtime secrets** in the Environment linked to this repo (mirror Infisical key names).
2. For **build** steps that need tokens, add **build secrets** separately.
3. On the Grok VM, use Infisical/Doppler or `~/.config/thunderstone/env` so the **worker** sees the same keys.
4. Prefer **MCP OAuth** (GitHub plugin, etc.) over duplicating tokens in every store.

## Verification

```bash
node scripts/env-doctor.mjs
THUNDERSTONE_SURFACE=cloud node scripts/env-doctor.mjs
bash scripts/doctor.sh
```

## Do not

- Commit `.env`, `.env.local`, or tokens.
- Store secrets in Google Drive or brief markdown.
- Put secret **values** in `config/env.registry.json` (names and documentation only).
