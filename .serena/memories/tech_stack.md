# Tech stack
- Shell-first project: POSIX/Bash scripts plus Node ESM helpers; Node >=22 required.
- npm lockfile is authoritative; sole dev dependency is Husky 9.1.7.
- Local MCP config exposes Context7, lean-ctx, and Caveman Cloud; it contains commands only, no credentials.
- Test/lint foundation: Bash, ShellCheck, Node JSON/config parsing, project test scripts.