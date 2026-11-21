## Summary
<!-- What changed and why, in 1-3 lines. Link the issue: "Closes #N". -->

## Validation
<!-- Commands run and results, e.g. `npm test`, `bash scripts/check-hygiene.sh`. -->
- [ ] `npm test` passes
- [ ] `bash scripts/check-hygiene.sh` passes

## Secrets
- [ ] No keys, tokens or `.env` values added (names only in `.env.example`)
- [ ] No absolute local paths or personal details; commits use the repo's public noreply identity (checked by `scripts/check-hygiene.sh`)

## Risks
<!-- Rollback plan, blast radius, anything reviewers should look at first. -->

## Agent receipt
<!-- Filled by Git-Scout when the agent pipeline validates this PR. People opening a PR by hand: tick "Manual PR". -->
- [ ] Manual PR (no agent pipeline)

| Check | Value | Evidence |
|---|---|---|
| Review threads | resolved _/_ (fixed _, declined with reason _) | |
| Fix rounds / levels | rounds _; levels L_ | |
| Tests | `npm test` rc _ | |
| Secret scan | hygiene + gitleaks rc _ | |
| Branch state | mergeStateStatus _ ; head `sha` ; update-branch used _ | |
| Required checks | validate _ hygiene _ gitleaks _ | |
| Needs DT | none / list | |

<!-- Review: opened PRs get one automatic AI review (CodeRabbit + cubic). For another pass, comment `@coderabbitai review`
     or `@cubic-dev-ai incremental review`. Mark as draft, add "WIP" to the title or the `agent:wip` label to skip it while iterating.
     Add "@coderabbitai" to the title to have CodeRabbit write a Conventional Commits title.
     If a PR is superseded by another, close it with a short comment instead of leaving it open for re-review. -->
