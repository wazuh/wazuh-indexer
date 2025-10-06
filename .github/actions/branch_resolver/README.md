# Branch Resolver Action

A GitHub Action that automatically determines the correct branch to use for dependent repositories (`wazuh-indexer-plugins` and `wazuh-indexer-reporting`) based on the current branch and VERSION.json files.

## Overview

When working with multiple related repositories, it's common to have issues matching branch names across them. This action resolves the correct branch for each dependent repository using the following logic:

1. **Direct match**: If a branch with the same name exists in the dependent repo, use it
2. **Version-based fallback**: If the branch doesn't exist, extract the version from another repo's VERSION.json and use the corresponding version branch (e.g., `4.12.1`)
3. **Current repo fallback**: If no branches are found in any dependent repo, use the current repo's VERSION.json to determine the branch

## Usage

### In a Workflow

```yaml
jobs:
  resolve-branches:
    runs-on: ubuntu-24.04
    outputs:
      wazuh_plugins_ref: ${{ steps.resolve.outputs.wazuh_indexer_plugins_branch }}
      reporting_plugin_ref: ${{ steps.resolve.outputs.wazuh_indexer_reporting_branch }}
    steps:
      - uses: actions/checkout@v5
      
      - name: Resolve branches
        id: resolve
        uses: ./.github/actions/branch_resolver
        with:
          branch: ${{ github.ref_name }}
      
      - name: Display resolved branches
        run: |
          echo "Plugins branch: ${{ steps.resolve.outputs.wazuh_indexer_plugins_branch }}"
          echo "Reporting branch: ${{ steps.resolve.outputs.wazuh_indexer_reporting_branch }}"

  build-with-resolved-branches:
    needs: [resolve-branches]
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v5
        with:
          repository: wazuh/wazuh-indexer-plugins
          ref: ${{ needs.resolve-branches.outputs.wazuh_plugins_ref }}
      
      - name: Build plugins
        run: ./gradlew build
```

### Standalone Script Usage

You can also run the underlying script directly from the command line:

```bash
bash .github/actions/branch_resolver/resolve-branches.sh feature-branch
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `branch` | Branch name to check and resolve | Yes | - |

## Outputs

| Output | Description |
|--------|-------------|
| `wazuh_indexer_plugins_branch` | Resolved branch name for wazuh-indexer-plugins repository |
| `wazuh_indexer_reporting_branch` | Resolved branch name for wazuh-indexer-reporting repository |

## How It Works

### Branch Resolution Logic

The action follows this decision tree for each dependent repository:

```
1. Does the input branch exist in the dependent repo?
   ├─ YES → Use that branch
   └─ NO → Continue to step 2

2. Does the input branch exist in any other dependent repo?
   ├─ YES → Extract version from that repo's VERSION.json
   │        └─ Use version-based branch (e.g., 5.0.0 → main, 4.12.1 → 4.12.1)
   └─ NO → Continue to step 3

3. Does VERSION.json exist in current repo?
   ├─ YES → Use version-based branch from current repo
   └─ NO → ERROR: No fallback available
```

### Version to Branch Mapping

- `5.0.0` → `main`
- `X.Y.Z` → `X.Y.Z` (e.g., `4.12.1` → `4.12.1`)

> **Note:** Currently, only `5.0.0` maps to `main`. All other versions map directly to their full version string.

## Output Format

The script outputs branch assignments in `key=value` format:

```
wazuh-indexer-plugins=feature-branch
wazuh-indexer-reporting=main
```

Diagnostic messages are sent to stderr, allowing easy parsing of stdout.

## Examples

### Example 1: Direct Branch Match

**Input:** `feature-xyz` branch exists in both dependent repos

**Output:**
```
wazuh-indexer-plugins=feature-xyz
wazuh-indexer-reporting=feature-xyz
```

### Example 2: Partial Match with Fallback

**Input:** `feature-xyz` exists in plugins but not in reporting

**Scenario:** `feature-xyz` has VERSION.json with version `4.12.1`

**Output:**
```
wazuh-indexer-plugins=feature-xyz
wazuh-indexer-reporting=4.10
```

### Example 3: No Match, Current Repo Fallback

**Input:** `feature-xyz` doesn't exist in any dependent repo

**Scenario:** Current repo has VERSION.json with version `4.13.1`

**Output:**
```
wazuh-indexer-plugins=4.13.1
wazuh-indexer-reporting=4.13.1
```

## Dependencies

- **bash**: Shell scripting
- **jq**: JSON parsing
- **git**: Repository operations
- **curl**: Fetching VERSION.json from GitHub
- **awk**: Text processing

All dependencies are available in standard GitHub Actions runners.

## Files

```
.github/actions/branch_resolver/
├── action.yml              # GitHub Action metadata
├── resolve-branches.sh     # Core branch resolution script
└── README.md              # This documentation
```

## Environment Requirements

- The script expects to be run from within a git repository
- The repository should contain a `.github` directory (used to locate project root)
- Internet access is required to check remote repositories

## Error Handling

The action will fail with a non-zero exit code in the following scenarios:

1. No branch name provided
2. Branch not found in any repo and no VERSION.json available
3. Unable to parse VERSION.json files
4. Network errors when accessing remote repositories

Error messages are sent to stderr and will appear in the GitHub Actions log.

## Customization

To add more dependent repositories, edit `resolve-branches.sh`:

```bash
REPOS=(
    "wazuh-indexer-plugins"
    "wazuh-indexer-reporting"
    "your-new-repo"  # Add here
)
REPO_URLS=(
    "https://github.com/wazuh/wazuh-indexer-plugins.git"
    "https://github.com/wazuh/wazuh-indexer-reporting.git"
    "https://github.com/wazuh/your-new-repo.git"  # Add here
)
```

Then update `action.yml` to add corresponding outputs:

```yaml
outputs:
  your_new_repo_branch:
    description: "Branch for your-new-repo"
    value: ${{ steps.resolve.outputs.your_new_repo_branch }}
```

## Troubleshooting

### Debug Mode

To see detailed output when running locally:

```bash
bash -x .github/actions/branch_resolver/resolve-branches.sh feature-branch
```

### Common Issues

**Issue:** "Permission denied" when running script
```bash
# Solution: Make script executable
chmod +x .github/actions/branch_resolver/resolve-branches.sh
```

**Issue:** Empty outputs in GitHub Actions
```bash
# Solution: Add debug step to verify outputs
- name: Debug outputs
  run: |
    echo "Plugins: ${{ steps.resolve.outputs.wazuh_indexer_plugins_branch }}"
    echo "Reporting: ${{ steps.resolve.outputs.wazuh_indexer_reporting_branch }}"
```

**Issue:** VERSION.json not found
```bash
# Solution: Ensure VERSION.json exists in repository root with format:
# { "version": "X.Y.Z" }
```
