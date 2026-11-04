# METRA 2027 — Operational Readiness Snapshot

> Snapshot date: 2026-11-04. Read-only audit of the new METRA Supabase project. This report is a point-in-time inventory, not an approval or operational certification.

## Scope and data protection

- Audited project: `tbdnklyxjvbrilvnwgmq`.
- The legacy database was not modified.
- No station was approved, activated, or assigned coordinates by this audit.
- No Auth user, administrator, reviewer, permission grant, or synthetic operational observation was created.
- All counts below are read-only queries against the new project.

## Current readiness

| Area | Observed state | Operational implication |
|---|---:|---|
| Non-demo stations | 62 | Catalogue records are present |
| Classic stations | 29 | Retain separate map marker styling |
| Automatic stations | 33 | Retain separate map marker styling |
| Stations pending catalogue approval | 62 | Human review is still required |
| Stations marked operationally unverified | 62 | Do not present as confirmed active stations |
| Stations with a current coordinate record | 50 | Coordinates exist, but station approval/operational verification remain separate |
| Stations without a current coordinate record | 12 | Must remain unlocated until a source is verified |
| Archived observation envelopes | 58,059 | Historical archive is populated |
| Archived envelopes without `station_id` | 1,251 | Reconciliation is required; do not infer station identity |
| Operational observations | 0 | Live user-entered observation workflow has no production records |
| Supabase Auth users | 0 | No real account is available for end-to-end authorization testing |
| Registration requests | 0 | Two-stage registration workflow has not yet been exercised with real users |

## Stations without a current verified coordinate record

The following 12 classic stations have no current row in `station_coordinates`:

| Local code | Station |
|---:|---|
| 20 | الإدارة العامة |
| 13 | البوكمال |
| 23 | بوقا |
| 24 | حلب الجامعية |
| 16 | حمام واصل |
| 21 | درعا |
| 15 | دير الزور |
| 25 | زاهد |
| 11 | صحنايا |
| 29 | عين العرب الجنوبية |
| 6 | محطة حماه |
| 1 | مركز بحوث الغاب |

Do not replace missing station coordinates with town-centre coordinates, geocoded place names, or guessed values. Add a coordinate only after receiving an authoritative station-specific source, field survey, GPS record, or explicitly reviewed manual verification. Preserve source reference and accuracy metadata.

## Unlinked historical observation envelopes

The 1,251 records with a null `station_id` have the following source-name distribution:

| Source station name | Records |
|---|---:|
| مطار اللاذقية | 1,102 |
| غير محدد | 105 |
| محطة حلب | 38 |
| الكريم | 4 |
| دمشق | 1 |
| Empty / null | 1 |
| **Total** | **1,251** |

These labels are not sufficient by themselves to establish a reliable mapping to a station catalogue record. Reconciliation should use source-system identifiers, documented station codes, provenance, and domain-owner review. Keep unresolved rows unlinked; never attach them to a similarly named or geographically nearby station merely to increase the linked-record count.

## Safe path to operational activation

1. Confirm the authorized meteorological authority and station owners.
2. Review each station's identity, type, owner, code, source provenance, and current coordinates.
3. Approve catalogue records through the station-review workflow using an authorized reviewer.
4. Verify operational status independently from catalogue approval; only then mark a station active.
5. Provision real users through the approved identity process. Keep system-level roles non-requestable and least-privilege.
6. Exercise station-level and system-level registration approvals with authorized test accounts, then revoke temporary test grants.
7. Submit, review, return, and approve controlled test observations; verify audit events and idempotent retries.
8. Reconcile historical envelopes only when a source-backed mapping is available.
9. Validate the deployed web build and authenticated end-to-end workflows before declaring production readiness.

## Technical controls already present

- All deployed METRA Edge Functions require JWT verification.
- Registration and observation decisions are routed through server-side authorization and transactional RPCs.
- The approval queue uses bounded query batches and stable pagination.
- CI type-checks the Edge Functions, runs their validation/permission/batching tests, analyzes Flutter, runs Flutter tests, builds the web release, and uploads the artifact.
- The Supabase security advisor returned no lint findings in the 2026-11-04 audit.

## Migration source integrity

A separate repository/database reconciliation found 57 applied migrations in the new Supabase project, while only 8 migration SQL files are present in the repository. Seven match the database history exactly, one has a filename mismatch, and 49 applied migrations have no same-version source file. The live schema is present, but the repository cannot yet reproduce it from its committed migration history. Do not reset the database or replay historical migrations to address this. Recover exact sources or create a reviewed reconstructed baseline and test it against a disposable database first. See [migration source reconciliation](MIGRATION_SOURCE_RECONCILIATION_2026-11-04.md).

## Release gate

A green CI build is necessary but is not equivalent to production readiness. The project remains blocked on real authorized identities, reviewed station records, station-specific evidence for missing coordinates, operational verification, and end-to-end acceptance tests.
