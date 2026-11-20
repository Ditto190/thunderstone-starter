# Suggested commands
- Bootstrap/run: `sh scripts/bootstrap.sh`; `bash scripts/resume.sh`.
- Health: `bash scripts/doctor.sh`.
- Validate: `npm test`; lint: `npm run lint`; whitespace: `npm run format:check`.
- Task execution: `node scripts/env-run.mjs bash scripts/run-task.sh workspace/briefs/<brief>.md`.
- Cursor bridge status: `bash scripts/cursor-worker.sh status`.
- Opt-in local checkpoint only: `ALLOW_LOCAL_COMMITS=1 bash scripts/checkpoint.sh "<message>" <explicit-files>`.