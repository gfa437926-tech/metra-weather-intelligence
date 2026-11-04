# Supabase migration source reconciliation

Audit date: 2026-11-04  
Target project: `tbdnklyxjvbrilvnwgmq`  
Repository: `gfa437926-tech/metra-weather-intelligence2026`, branch `main`

## Findings

- Database migration history contains **57** applied migrations.
- The repository contains **24** SQL migration files.
- **24** repository files match both the database migration version and name exactly.
- **0** migrations have a matching version but a different filename.
- **33** applied migrations have no same-version SQL source file in the repository.

This is a migration-source drift issue. It does not mean the database schema is absent; the database currently has the applied objects. It means the repository is not a complete reproducible history of how the database reached its current state.

## Filename mismatch

None. The migration source filename was aligned with the database history in commit `c563187b509190b254038d1aa8a358b6ff7a0c12`.

## Applied migrations with no same-version source file

The following 33 database migrations remain without exact source files in the active repository:

- `20261102154652_create_independent_station_catalogue.sql`
- `20261102155101_index_station_catalogue_foreign_keys.sql`
- `20261102155110_add_catalogue_integrity_triggers.sql`
- `20261102155119_lock_station_catalogue_client_access.sql`
- `20261102163034_enforce_station_temporal_integrity.sql`
- `20261102165436_add_identity_membership_and_station_assignment.sql`
- `20261102165505_lock_identity_tables_and_index_foreign_keys.sql`
- `20261102165724_add_user_profile_and_align_account_lifecycle.sql`
- `20261102165758_index_account_state_requester.sql`
- `20261102171030_add_station_source_provenance_and_demo_flags.sql`
- `20261102171037_support_unverified_station_operational_status.sql`
- `20261102172226_create_provenance_preserving_observation_store.sql`
- `20261102235913_create_registration_workflow_persistence.sql`
- `20261102235937_add_atomic_registration_submission_rpc.sql`
- `20261103000038_harden_registration_idempotency_checks.sql`
- `20261103000332_provision_least_privilege_api_runtime_role.sql`
- `20261103000835_add_atomic_two_stage_registration_approval.sql`
- `20261103000914_grant_runtime_registration_queue_read.sql`
- `20261103001045_harden_registration_approval_expected_state.sql`
- `20261103001209_grant_runtime_registration_audit_read.sql`
- `20261103001354_use_database_clock_for_registration_approval.sql`
- `20261103001407_move_registration_submission_rpc_to_private_schema.sql`
- `20261103001654_revoke_public_execute_from_approval_rpc.sql`
- `20261103001743_drop_obsolete_registration_approval_rpc.sql`
- `20261103001942_classify_existing_pending_registration_before_linked_account.sql`
- `20261103002006_fix_pending_registration_replay_classification.sql`
- `20261103010120_respect_scheduled_permission_revocation.sql`
- `20261103010435_add_registration_foreign_key_indexes.sql`
- `20261103122944_grant_runtime_station_coordinate_read.sql`
- `20261103123005_link_membership_and_assignment_roles.sql`
- `20261103123127_index_role_catalogue_foreign_keys.sql`
- `20261103162707_enforce_explicit_role_permission_allowlist.sql`
- `20261103162738_seed_conservative_observation_role_permissions.sql`

## Safe recovery plan

1. Preserve the current database as the source of truth; do not reset it.
2. Recover exact SQL from Git history, prior deployment artifacts, local developer copies, or trusted migration backups.
3. Where exact source cannot be recovered, reconstruct a clearly labelled baseline from current catalog definitions (tables, constraints, indexes, policies, triggers, functions, grants) and mark it as reconstructed rather than original.
4. Compare reconstructed definitions against the live database before committing.
5. Never reapply historical migrations merely to populate source files; their effects are already recorded in the database.
6. After recovery, verify a clean migration inventory and test the complete migration chain against a disposable Supabase branch/database before any production deployment.

## Additional source recovery completed on 2026-11-04

- The prior repository's `database/migrations` directory contained the source SQL for applied migrations `003` and `005` through `014`; these eleven files were restored to this repository using the exact version/name recorded in the new database.
- The corresponding live function definitions were inspected, and the authorization functions were confirmed non-executable by `anon` and `authenticated` and executable by `service_role` only. The role-permission rows introduced by these migrations were also confirmed present.
- The prior repository's `supabase/migrations` directory contains five observation migration sources, all already restored. Its migration directories contain no further source files for the remaining 33 missing migrations.

## Guardrails

- No historical migration was replayed during this audit. One new forward-only registration eligibility migration was applied and recorded as `20261104042128`.
- Five observation workflow migrations and eleven station/permission workflow migrations were recovered from the prior METRA repository (including its `database/migrations` directory) and restored under the exact version/name recorded in the new database. The recovered functions, execution privileges, and role-permission allow-list entries were checked against the live database. The new registration eligibility migration `20261104042128_require_approved_active_station_for_registration` is applied and its exact SQL source is committed.
- The legacy database was not accessed or changed.
