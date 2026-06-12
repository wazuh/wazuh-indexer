# Workflows - Best Practices

## Pull Request lifecycle

### 1. Create PRs as Draft

All Pull Requests should be created in **Draft** status. Automated workflows (build, tests, code quality checks) **do not run on Draft PRs**, which saves GHA minutes and avoids unnecessary noise.

### 2. Validate locally before requesting review

Before marking the PR as ready, make sure to:

- **Build** the project successfully.
- **Run the tests** locally and verify they pass.

This prevents avoidable CI failures that waste runner time and delay reviews.

### 3. Mark as Ready for Review

Once all changes are complete and locally validated:

1. Click **"Ready for review"** on the PR.
2. Move the linked issue to **Pending review**.

This is when workflows will be triggered for the first time.

## Changelog

Every PR is expected to include a changelog entry. The `5_codequality_changelog.yml` workflow enforces this.

- If the linked issue belongs to a **private repository**, do not add a changelog entry. Apply the **`skip-changelog`** label to the PR to bypass the check.
- If the PR genuinely does not require a changelog update, apply the **`skip-changelog`** label as well.
