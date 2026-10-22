---
description: Windows environment and PowerShell execution guidelines
globs: ["**/*"]
always_on: true
---

# Windows & PowerShell Development Guidelines

When executing commands or writing code on the Windows host environment:

## 1. Shell & CLI Conventions
- **Command Runner:** Default shell is PowerShell 7+. Do not invoke Bash commands directly in Windows shell sessions unless targeting WSL or Git Bash explicitly.
- **Python Launcher:** Invoke Python using `py` (e.g. `py script.py` or `py -m pip`), as Python execution aliases on Windows may point to the `py` launcher rather than a bare Python executable.
- **Node.js:** Node is v24+ on Windows PATH. Always use `node <script>` and `npm`.

## 2. Path Handling
- Always use forward slashes (`/`) or `Path` abstractions (`pathlib.Path` in Python, `path.resolve` in Node) to ensure compatibility across Windows and Linux.
- Never hardcode Windows-specific absolute drive letters in committed project code, briefs, or receipts. Use relative paths from the repository root.

## 3. PowerShell Operator Caveats
- Use `;` or separate statements rather than POSIX `&&` when running older PowerShell compatibility modes.
- Avoid piping output directly into text commands that lose exit codes; test `$LASTEXITCODE` for reliability.
- Redirection of stderr: use `2>$null` or `2>&1` with caution when capturing exit statuses.
