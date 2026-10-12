# Thunderstone VM Starter

Drive-first starter for Grok Bot computers and Cursor Cloud Agents. Version 1.0.0.

## Start in the Grok VM

Download and extract the ZIP to a permanent directory, for example a `thunderstone-starter` folder in your workspace. Open Xfce Terminal in that directory and run:

```sh
sh scripts/bootstrap.sh
bash scripts/install-desktop.sh
bash scripts/resume.sh
```

The first command is POSIX sh: it can install Bash even when Bash is missing. Supports Debian/Ubuntu apt, Fedora dnf and Alpine apk; requires root or noninteractive sudo for missing OS packages. It does not replace the desktop, init system, shell defaults, or install Docker. If privileges are unavailable it stops with an actionable error.

Tools installed from the distribution repositories: Bash, tmux, Git, curl, certificates, unzip/zip, jq, ripgrep, fzf, Python, rclone, ShellCheck, make and compiler tools. Package versions follow the VM distribution repositories; this is not a byte-identical pinned OS image. Python dependencies are unnecessary. Distro Node and npm are installed only when Node 22+ is not already on PATH, so an existing Node 22 is left alone. If Node is below 22, bootstrap installs Node 22.23.2 user-locally from nodejs.org and checks the archive against the HTTPS-published checksums. It never overwrites an existing local binary. Alpine requires a sufficiently recent distro Node instead. Cursor CLI uses the official downloaded installer only when missing; the installer is retained locally for audit. Grok CLI is detected but not installed through guessed marketplace commands.

Xfce is a lightweight desktop environment, not a shell or operating system. Keep it: https://www.xfce.org/about

## Startup semantics

`install-desktop.sh` adds a named desktop launcher and an XDG login-autostart entry under the current user. It refuses to overwrite differing existing entries. Autostart runs at desktop session login, not every time the remote computer viewer opens. Every Bot must invoke `resume.sh` before work as the reliable resume path. Xfce can restore saved sessions as well as autostart entries: https://docs.xfce.org/xfce/xfce4-session/preferences

Resume uses a kernel file lock, keeps one `thunderstone` session, and never starts a paid agent job automatically. tmux survives terminal disconnects but not VM reboot; resume recreates the terminal session after reboot. systemd is detected, not assumed, and never replaced. No background cloud worker or inbound service is installed by default.

## Cursor Cloud

Promote the extracted project to GitHub when active development starts. The included `.cursor/environment.json` runs bootstrap for builds and resume on agent start. In multi-repo Cloud environments, install and start run with working directory `/agent`, so those commands use absolute paths under `/agent/repos/thunderstone-starter/`. Do not copy this package's package.json over an existing application's package.json; merge scripts and dev dependencies and retain the application's lockfile.

Set runtime secrets in Cursor settings. Build secrets are separate and should be supplied only if installation needs them. Cursor install runs during a Build; start runs on boot: https://cursor.com/docs/cloud-agent/setup

Cursor CLI installer reference: https://cursor.com/docs/cli/installation

Hook lifecycle, the pinned Composio skill, and the connector catalogue are described in `docs/engineering-forge.md`.

For a task, write a brief and run:

```sh
node scripts/env-run.mjs bash scripts/run-task.sh workspace/briefs/TASK-001.md
```

This launches Cursor CLI once, in the current checkout, without auto-approval flags. It does not recursively launch another Cursor agent inside a Cursor Cloud agent: Cloud agents execute directly using their existing agent runtime. Authenticate with `agent login` once or inject `CURSOR_API_KEY`. Do not infer that a login here registers a Cursor My Machines worker.

## Environment and Drive

`env-run.mjs` loads real dotenv syntax with Node's parser. Precedence: injected environment, `/run/secrets/thunderstone.env`, `~/.config/thunderstone/env`, project `.env.local`, project `.env.defaults`. It never sources shell code or prints values. Node 22+ is required. Explicit empty environment values remain authoritative.

GitHub Actions secrets are not retrievable from a VM. Map them explicitly to environment variables inside an authorized workflow; provision VM/Cursor secrets separately. A connected Drive tool in Grok does not automatically authenticate rclone inside its VM.

For unattended Drive access inject `RCLONE_CONFIG` pointing to a protected rclone configuration, or `RCLONE_CONFIG_GDRIVE_TYPE=drive` and the relevant rclone remote environment fields. For personal My Drive use user OAuth and your own Google OAuth client ID; service accounts are primarily suitable for appropriately authorized shared drives and have storage/ownership constraints. Configure initially with `rclone config`. Reference: https://rclone.org/drive/

Download a released starter into a new directory:

```sh
rclone copyto 'gdrive:99_SYSTEM/AUTOMATION/Thunderstone VM Starter/thunderstone-starter-1.0.0.zip' starter.zip
unzip starter.zip
cd thunderstone-starter
sha256sum -c manifest.sha256
```

Checksums detect corruption, not malicious replacement of both package and checksum. Trust the Drive release owner.

Export ONLY curated files to `workspace/exports/`, review for secrets, then:

```sh
node scripts/env-run.mjs bash scripts/export-drive.sh
```

Exports are additive to unique run folders; no Drive sync/delete. No raw agent logs are exported automatically. Set `DRIVE_EXPORT_ROOT` to the active project's export path before use.

## Git, hooks and CI

Before promotion, no Git remote is created. Initialize locally when ready (`git init -b work/bootstrap`), set your own Git identity, then `npm run prepare`. Husky runs validation before commit and push. Local checkpoint automation is opt-in via `ALLOW_LOCAL_COMMITS=1`; specify individual paths, never blanket-stage. Checkpoints refuse main/master and a pre-existing staged diff. Pushes, PR creation and deployment remain separate approved actions.

```sh
ALLOW_LOCAL_COMMITS=1 bash scripts/checkpoint.sh "chore: validated checkpoint" README.md
```

CI installs locked dependencies and runs the same validation. Hooks are bypassable; CI is the authoritative check. Add application tests/build/lint to `npm test` when adopting this starter: the included tests validate infrastructure, not an application. Husky reference: https://typicode.github.io/husky/get-started.html

## Bot instruction

You are Chief Thunder-Terminal of the Thunderstone Clan. Read AGENTS.md and your assigned brief, run scripts/resume.sh, then use Cursor CLI for bounded execution unless already inside Cursor. Prefer CLI/API retrieval over GUI clicks. Read only relevant files. Save evidence locally; report outcome, files, checks, blocker and next action briefly. Chiefs route, Grunts implement, Watchers verify. No recursive delegation or automatic chat-message relay. Caveman tone is opt-in only.

## Verification limits

Package syntax and infrastructure tests are validated in the build sandbox. Actual Grok VM privileges, distro repositories, desktop persistence, Cursor login, Drive OAuth and reboot behavior must be verified in the target VM. No remote VM installation is claimed by providing this archive.
