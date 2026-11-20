# Infisical secrets

This is an optional way to provide runtime secrets without keeping provider API keys in project files. Infisical stores the values; the launcher retrieves only the selected project, environment, and folder for the process it starts.

## Configure the project

1. Create a Secrets Management project named `thunderstone` in Infisical.
2. Create a `dev` environment and a `/coding` folder in that environment.
3. Add one development provider secret, for example `XAI_API_KEY`. Do not put its value in this repository.
4. Copy the project ID and non-secret settings from `config/infisical.example.env` into `.env.local` or your protected runtime environment. Merge them into an existing `.env.local`; do not overwrite unrelated settings.

## Use it on your own machine

Install the Infisical CLI using its [official install instructions](https://infisical.com/docs/cli/usage), then authenticate interactively:

```sh
infisical login
infisical login status
```

Run a harmless presence check. It reports whether the key exists, never its value:

```sh
node scripts/env-run.mjs bash scripts/infisical-run.sh -- \
  node -e 'if (!process.env.XAI_API_KEY) process.exit(1); console.log("XAI_API_KEY present")'
```

If this succeeds, start a real application or tool the same way:

```sh
node scripts/env-run.mjs bash scripts/infisical-run.sh -- npm run dev
```

The wrapper requires `INFISICAL_PROJECT_ID`; it defaults to environment `dev` and path `/coding`. Override these with `INFISICAL_ENVIRONMENT` and `INFISICAL_SECRET_PATH`. It passes project, environment, and path explicitly, so it does not rely on `infisical init`.

## Connect an unattended Linux VM

Create a separate Infisical machine identity for the worker, then assign it to the project with the minimum read access it needs. Identity authentication and project authorization are separate steps: creating a machine identity alone does not grant access to project secrets.

Use the hosting platform's protected runtime-secret facility for `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID` and `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`; do not put the client secret in this repository or in a shared `.env.local`. Also provide `INFISICAL_PROJECT_ID`. Set `INFISICAL_DOMAIN` only for EU Cloud, a dedicated instance, or self-hosting; see Infisical's [machine identity CLI instructions](https://infisical.com/docs/cli/usage).

The same command works on the VM:

```sh
node scripts/env-run.mjs bash scripts/infisical-run.sh -- \
  node -e 'if (!process.env.XAI_API_KEY) process.exit(1); console.log("XAI_API_KEY present")'
```

The CLI reads Universal Auth credentials from their environment variables. The wrapper removes those credentials and Infisical access-token variables from the child process, but the child still receives the requested provider secrets. An agent or tool running as that child can read any secret injected into its environment. For higher-risk agents, evaluate a credential proxy or a platform-native OIDC/workload identity instead of injecting provider keys directly.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| CLI is missing | Install Infisical CLI and confirm `infisical --version`. |
| Login or fetch fails | Verify instance/domain, machine identity credentials, expiry, and project assignment/permissions. |
| Command runs but a key is missing | Verify the environment slug, folder path, and exact secret variable name. |
| Works locally but not on VM | Ensure the VM has the project ID and protected machine credentials; the CLI does not reuse your laptop login. |

Run the local launcher test with `bash tests/infisical-run-test.sh`; it uses a fake CLI and does not contact Infisical.
