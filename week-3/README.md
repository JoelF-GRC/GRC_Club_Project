# Week 3 starter: Build the Gate

A skeleton GitHub Actions workflow. You write the steps. The goal is a gate that runs your week 2 policies on every pull request and blocks the ones that break a control.

## Repo layout this assumes

Your challenge repo should have, by now:

```
terraform/        # your week 1 build
policies/         # your week 2 policies
plan.json         # terraform show -json of your compliant plan, committed
.github/workflows/grc-gate.yml   # this file, completed
```

Generate `plan.json` from your week 1 dir and commit it:

```bash
terraform plan -out=tfplan && terraform show -json tfplan > ../plan.json
```

## What to build

Complete the TODOs in `grc-gate.yml`:

1. Install Conftest at a pinned version.
2. Run your three policy namespaces against `plan.json`, write results to `evidence/conftest-results.json`, and fail the job on any policy failure.
3. Upload `evidence/` as an artifact with `if: always()` so it is saved on failure too.

## The two-PR demonstration (this is the deliverable)

1. **Green PR.** Open a pull request with your compliant `plan.json`. The gate runs, passes, the PR is mergeable.
2. **Red PR.** Open a pull request where the plan breaks a control (regenerate `plan.json` from a workspace with encryption removed, or hand-edit one flag to false). The gate runs, fails, and with branch protection on, the merge is blocked.

Turn on branch protection (Settings, Branches) and require the `grc-gate` check, so the red PR genuinely cannot merge. Screenshot both checks.

## Done when

- A PR triggers the workflow and it appears in the Actions tab.
- The compliant PR ends green. The violating PR ends red and is blocked.
- An evidence artifact is attached to both runs.

## Stretch: generate the plan in CI with OIDC

Committing `plan.json` is the simple, free, no-secrets path. The production version has CI generate the plan itself by assuming an AWS role through GitHub OIDC, so there are no stored keys. The brief explains the trust setup if you want to build it.

## What got built

This repo keeps each week in its own folder rather than the flat `terraform/` / `policies/` / `plan.json` layout above, so the finished workflow points at `week-2/policies` and `week-2/plan.json` directly. The workflow itself lives at `.github/workflows/grc-gate.yml` at the repo root, not under `week-3/`, since GitHub Actions only triggers workflows from the root `.github/workflows/` directory.

The three TODOs became:

1. **Install Conftest**, pinned to `0.68.2`. The install step downloads the release tarball and `checksums.txt` for that version and runs `sha256sum -c` before trusting the binary, rather than piping an installer script straight into a shell.
2. **Run the policy gate** with `conftest test --policy week-2/policies --all-namespaces --output json week-2/plan.json`, piped through `tee evidence/conftest-results.json` under `set -o pipefail`. Without `pipefail`, `tee` always exits 0 and swallows Conftest's failure exit code, which would make the gate pass even on a real denial.
3. **Upload `evidence/`** via `actions/upload-artifact@v4` with `if: always()`, so the artifact is attached whether the job passes or fails.

### The two-PR demonstration, as it actually ran

- **Green PR** ([#1](https://github.com/JoelF-GRC/GRC_Club_Project/pull/1)): the compliant `week-2/plan.json`. `grc-gate` passed all three namespaces (SC-28, AC-3, CM-6). Merged into `main`.
- **Red PR** ([#2](https://github.com/JoelF-GRC/GRC_Club_Project/pull/2)): `week-2/plan.json` swapped for the `week-2/evidence/broken/plan.json` fixture (log bucket missing encryption and public access block, both buckets missing the `ComplianceScope` tag). `grc-gate` failed with four denials across all three namespaces. Closed without merging; its only purpose was demonstrating the block.
- **Evidence PR** ([#3](https://github.com/JoelF-GRC/GRC_Club_Project/pull/3)): adds the two screenshots below. Merged into `main`.

Branch protection on `main` requires the `grc-gate` check (`strict: true`, `enforce_admins: true`), which is what turned PR #2's failing check into an actual blocked merge instead of a red X someone could ignore.

Screenshots, captured from the PRs above:

- `evidence/pr1-green-passed.png`: PR #1, `grc-gate` passing, merge button active.
- `evidence/pr2-red-blocked.png`: PR #2, `grc-gate` failing and marked Required, merge button disabled.
