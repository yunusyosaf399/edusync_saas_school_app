# DB-02 I03 — locked source and future-effective Enrollment/Roll gate

**2026-10-23 · owner: DB-02 · status: unmerged draft pending exact-head CI.**

Parent: [I02 PR #144](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/144), head `ebd32cdc0be05451db75477b98371d568f00df40`. Design authority: [P01 PR #138](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/138), [P02 PR #142](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/142). No DB-01/DB-03/DB-04 source changes, and no Supabase hosted SQL.

## Implemented private behavior

Append-only inactive draft `effect49_01_db02_locked_future_source_preflight.sql.draft` replaces **two existing Student-owned private functions**, with unchanged signatures, returns, fixed search_path and grants:

1. `d1_roll_policy_change_preflight` retains School-first `d1_enrollment_place_lock_school`, computes School-local `d1_roll_business_date` **after locking**, rejects END/schedule/repeated INIT and stale source identity. REPLACE locks the exact currently open source policy (UUID, revision, mode, starting number, effective_from, effective_until=NULL), denies same-day closure and any existing successor, then locks the original allocator set UUID-ordered. No policy rows are mutated. All future Enrollment/Roll School ancestry comes from the existing academic-owned `d1_enrollment_place_destination(section_uuid)` private projection, not Student-executor direct SELECT on academic Class/Section Offering tables; this respects the frozen Academic→Student least-privilege boundary.
2. **New INIT conflict check:** after the School lock and before accepting an empty first revision, reject a persisted School Enrollment beginning at/after the School-local date, even when that Enrollment is missing its Roll. This is an inconsistent committed future-placement anomaly, not a reason to invent a policy or number.
3. **New REPLACE conflict checks:** after the School and source revision lock, reject a future-starting `roll_allocations` row joined through its Enrollment→Section→Class Offering and recorded policy revision **when either ancestry belongs to this School**, regardless of the source revision it references or whether the Enrollment itself started earlier. Also reject any School-owned persisted Enrollment beginning at/after today, even without an allocation. Prior preflight checked only future Rolls on the currently open policy. The new implementation keeps the original `D1_ROLL_POLICY_REPLACE_FUTURE_ROLL` label for future Rolls and selects `D1_ROLL_POLICY_REPLACE_FUTURE_ENROLLMENT` for otherwise uncovered future Enrollments. `INIT` uses `D1_ROLL_POLICY_INIT_FUTURE_ENROLLMENT`.
4. I02's Student-owned `d1_roll_policy_command_context` now **calls the complete source preflight after** verified Principal / fixed shared receipt/idempotency, School lock and current School ALL grant, but **before** the final exact P1 UUID recheck and before returning any private context. No alternate branch can skip a stale-source/future-commitment check. It fails closed on preflight errors.
5. The SELECT checks intentionally do not lock child Enrollments before the School/Policy lock. The existing PLACE/MOVE School anchor provides serialization; future **two-backend** proof that placement honors it is still separately tracked in T05, and future APPROVAL APPLY must perform an independent fresh current-intent preflight in I10.

A successfully accepted Enrollment/Roll whose `effective_from < School-local today` is not a future-starting commitment solely because its interval crosses today. The existing numeric Roll allocation and historical policy ancestry remain unchanged. **No new public/RPC endpoint, policy/allocator writes, receipt creation, audit, event, permission enablement, Workflow EXECUTE, private table privilege, or production deployment.**

## Validation

Rollback-only test `91_db02_locked_future_commitments.sql`, **18 pgTAP assertions**, covers owner/SECURITY DEFINER/private EXECUTE, initial empty School success, INIT future Enrollment denial, exact source acceptance and stale start-value rejection, historical Enrollment/Roll spanning today allowed, future new Roll denied even on an older Enrollment, future Enrollment missing Roll denied, and zero revision/high-water/event changes. All synthetic Enrollment/School fixtures ROLLBACK. Existing DB-02 #83 (18), #89 (28), #90 (24) must still pass.

**Catalog unchanged:** 250 draft fragments become 251; **552 functions / 534 security definers / 395 private / 157 app**, 34/34 forced RLS, zero private client EXECUTE. Accepted business assertions expected **3,422 = 3,404 + 18**; do **not** claim they passed before actual exact-head CI.

## Remaining work / hard gates

- **I04–I05:** write an actual atomic new policy revision and per-namespace allocator set after this gate, with rollback on any failure. This preflight alone does not change a School policy.
- **I06–I11:** receipts, audit, event, protected DIRECT/approval lifecycle, replay historical proof and exact request phases.
- **T05/T06:** genuine concurrent two-backend PLACE/MOVE versus REPLACE and authorization/revocation races; no concurrency result is inferred from this single-transaction suite.
- **G02/G03:** recomposition with actual current DB-01 and other owners, independent shared-security signoff still pending at [issue #131](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/131). Draft only; Migration 10 remains `.sql.draft`, and PR must not be merged/deployed based solely on these local checks.
