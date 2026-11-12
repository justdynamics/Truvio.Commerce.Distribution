# Edition ledger locks

Each layer declares `ledger.provides` for functions its payload demonstrates and
`ledger.requires` for capabilities it depends on or merely configures. The adjacent
comment explains exclusions. These are carriage declarations, not passing evidence.
For example, feature-pricing installs provider settings; sample-data carries the
price rows. The gallery add-on has no exact ledger function, so it claims none.

An edition locks the union of its provided functions' primary checks. Requirements
must exist in the same snapshot but do not add checks. The lock uses the skills
consumer contract's names: `repo`, `commit`, `manifest`, `digest`, `checkIds`.
`repo` is `dynamicweb/skills`; `manifest` is relative to that checkout. Foundry passes
the other four fields unchanged to the skills runner's build declaration.

The digest covers the complete release directory, using the pinned runner's
`Get-LedgerDigest`. Use canonical LF bytes: on Windows create the checkout with
`git -c core.autocrlf=false worktree add --detach <path> <commit>`. The validator
requires the exact commit and clean ledger and shared transport sources. It never
fetches or updates a producer on the caller's behalf.

Run `pwsh tools/ci/Validate-Distribution.ps1 -SkillsRoot <path>` and Pester on
`tools/ci/tests` with `TRUVIO_SKILLS_PATH` pointing to that checkout. CI explicitly
checks out the lock's revision. A future lock update also updates that CI ref;
validation rejects a checkout at the wrong revision. Unknown function/check ids,
digest differences, empty sets and extra or missing checks fail.

The first locks cover all five compositions. Layer patch versions change because
layer.json is part of the proven tree hash; payloads are unchanged. Existing release
records and bacpacs remain historical proof. The regenerated INDEX layer list does
not advance gateProven. A new composition must acquire its own proving record before
a release or stamp is advanced. Foundry keeps ledger identities and the report
digest beside that proof; its consumer never copies the skills runner.
