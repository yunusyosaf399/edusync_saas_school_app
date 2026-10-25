# DB02 G01 — suite registration and dependency review

G01 preserves all 112 existing full SQL filenames and all 4,292 assertions from the current composed DB01/DB02/Academic draft. Numeric labels are display/order labels, not globally unique suite IDs. In particular DB01 and DB02 both retain labels 82–86 and 89–92. No owner suite is renamed, renumbered, edited, dropped, or selected by an ambiguous numeric prefix.

## Enforced registry contract

`domain_business_ci.validate_test_registry` validates the complete manifest before any test subprocess starts. Every top-level `supabase/tests/domain/*.sql` file must be registered exactly once, use a basename with no path traversal, declare its exact positive integer pgTAP plan, retain the rollback transaction boundary and contain exactly one shared actor fixture include. Duplicate full filenames, duplicate ordinals within one owner namespace, unregistered SQL files, invalid plan counts and missing fixture/rollback boundaries fail the run before database execution.

Existing legacy suites 01–74 and `80_school_local_roll_business_date.sql` keep their names. Reserved owner components are `db01`, `db02`, `academic`, `db03` and `db04`. New suites use `<ordinal>_<owner>_<descriptive_topic>.sql`; ordinals may repeat between owners. Existing DB01/DB02 owner ordinals are retained, Academic 102/103 remain assigned, and new DB02 suites start at the next unused DB02 ordinal (currently 102). New DB03/DB04 suites may start their own numbering without colliding with DB01/DB02. Adding another owner component requires an explicit registry/doc update; no filename prefix grants SQL authority or completes that domain.

Nine tooling tests cover the current registry, allowed cross-owner collisions, rejected same-owner collisions, duplicate full filenames stopping before any subprocess, silently dropped registration, unknown future owner, reserved DB03/04 owners, invalid paths/counts/plans and transaction boundaries. Full Python tooling passes 389 tests. SQL/runtime behavior and pinned catalog remain unchanged by this increment.

## DB01 dependency review — observed 25 October 2026

| Component | Observed SHA | Required next integration step |
| --- | --- | --- |
| DB02 T08 draft PR #164 | `794bb999e726a9893bd6b774de23a579d11039f0` | Keep its complete owner chain and shared receipt overrides; already composed in #165/#166 |
| DB01/DB02 draft PR #165 | `35ddd360e5c159b8d74bbd18e6b185611f8ef158` | Preserve its APPLY/REPLACE races and canonical replay acceptance |
| Academic pool hook draft PR #166 | `327ccb7c1f557b2a619f2e0cd737fc3832c37eca` | Base for this registry increment; static #40209093755, Foundation #40209093779 and D1 #40209093746 all green, 4,292 assertions |
| DB03 draft PR #102 | `d9995a47295a5b6e0ddecf127a47453081517d98` | Still design-only; installed Student-create/Finance handoff needed before full DB01 integration |
| DB04 draft PR #103 | `98a2453e7314ee443dd09bb320cc474ef3fed168` | Still design-only; installed consumer handoffs and accepted lineage/version behavior needed |
| Observed main | `e526de3fd4668483623ef52cccc34d38d893c249` | Final G02/G04 must recompose the exact then-current main and owner heads, rather than claim that these draft previews are already merged |

#166 is based on #165, which is based on the DB01 policy-retirement integration branch. This G01 increment is stacked on #166. Keep both owners' SQL fragments and complete filename registrations in dependency order. The DB03/DB04 handoffs and independent security review still block full DB01 closure; they do not prevent this DB02 tooling gate.

## Completion boundary

G01 is a source/tooling engineering gate. Its proof is the preserved manifest and negative regression tests, with exact PR/commit/CI recorded in issue #69. G02 final latest-main recomposition, G03/P03 independent non-author review, G04 approved integration/merge, G05 final contract freeze and G06 authorized activation remain separate. This change does not activate Migration 10 or merge a PR.
