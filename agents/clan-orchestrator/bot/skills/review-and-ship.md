# review-and-ship (lane)

When this lane is active:

1. `git fetch origin main` and diff against `origin/main`.
2. Run `npm test` when starter scripts changed.
3. Summarize critical / warning / note findings.
4. Recommend commit + PR update; never push without explicit user approval.
