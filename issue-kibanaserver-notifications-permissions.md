# Title: Default notification channels fail: missing permissions for `kibanaserver`

## Description

After merging [wazuh/wazuh-indexer#1700](https://github.com/wazuh/wazuh-indexer/pull/1700) ("Add new security config"), the default notification channels stop working because the `kibanaserver` user no longer has the permissions it needs.

PR #1700 introduced/modified the following security config files to fix Content Manager permissions for the admin user (resolving [wazuh/wazuh-indexer-plugins#1325](https://github.com/wazuh/wazuh-indexer-plugins/issues/1325)):

- `action_groups.yml` — to make `plugin:content_manager/*` aliases work in `wazuh_admin` / `wazuh_demo` / `wazuh_readonly`.
- `roles.yml` — to fix the raw action names in `wazuh_full_access`.
- `roles_mapping.yml` — to give the admin user a role that actually grants Content Manager permission.

These changes appear to have regressed the permissions granted to `kibanaserver`, which are required to create/manage the default notification channels.

The regression was introduced by commit `0bae2230da299e290acca97d37d1ab2ee6fee8a4` on the `5.0.0` branch.

**Related:**
- Introduced by: [wazuh/wazuh-indexer#1700](https://github.com/wazuh/wazuh-indexer/pull/1700)
- Resolved by PR #1700: [wazuh/wazuh-indexer-plugins#1325](https://github.com/wazuh/wazuh-indexer-plugins/issues/1325)
- Packages: https://github.com/wazuh/wazuh-indexer/actions/runs/28451624874

**Host/Environment:**
- 5.0.0-latest

## Functional requirements

- The default notification channels must be created and function correctly out of the box.
- The `kibanaserver` user must have the permissions required to operate the notifications plugin (create/read/update/delete notification channels and configs).
- The Content Manager permissions added for the admin user in PR #1700 must remain intact — this fix must not regress that behavior.

## Implementation restrictions

- Changes must be limited to the security configuration (`action_groups.yml`, `roles.yml`, `roles_mapping.yml`) unless a code-level fix is proven necessary.
- Do not broaden permissions beyond what `kibanaserver` requires for notifications; keep the principle of least privilege.
- Preserve the fixes delivered by PR #1700 (admin Content Manager access).

## Plan

- [ ] Reproduce the failure: verify default notification channels break on a build containing commit `0bae2230da299e290acca97d37d1ab2ee6fee8a4`.
- [ ] Diff the security config before/after PR #1700 to identify the permission(s) removed from `kibanaserver`.
- [ ] Restore the missing `kibanaserver` permissions in the relevant security config file(s).
- [ ] Confirm the admin user still has Content Manager permissions (no regression of #1325).
- [ ] Build packages and validate default notification channels work end-to-end.
- [ ] Add/update tests or validation to guard against future security-config regressions.
