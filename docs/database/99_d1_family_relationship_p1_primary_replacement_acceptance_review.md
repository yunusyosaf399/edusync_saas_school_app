# D1 Effect 30 — P1 approved END with explicit selected-primary Family replacement

Date: 2026-10-10  
Verdict: **PASS — exact-source disposable local incremental acceptance. Full D1 OPEN.**  
PR: [#19](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/19)

## Tested source / required workflows

- Prior accepted main: `3eb365cace4c4c3045b066727ca62c325f60af89`; exact tested PR head: `cdf075818d199654cbd5a97d0649ef6451e0e5ce`; merge: `5765a209d99e09c6be0acc67788add96596bee93`, with the tested PR head as second parent. Only suite20 and its runner registration changed.
- [D1 local runtime #184](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38066355236): **PASS**. Suite `20_family_relationship_p1_primary_replacement.sql` **44/44**; business **837/837 across 20 suites**; post-D1 Foundation **220/220**; tooling unit tests **21/21**; **six observed-lock two-session races** (three Employee creation, three Family Principal membership P1 ADD/END/CORRECT). Lint error/warning PASS. Local catalog: 202 assembled non-executable draft fragments; 34/34 forced RLS, 540 final functions, 522 SECURITY DEFINER, no client private helper EXECUTE. Disposable database stopped.
- [Foundation #379](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38066355274): **PASS**, nine frozen migrations and 220/220 pgTAP assertions.
- This test-only two-file change did not trigger the path-filtered D1 static workflow. The unchanged accepted 202 SQL draft fragments passed [D1 static #115](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482552) and exact-head D1 runtime assembly, RLS, function and lint probes.

## Frozen behavioral assertions

Under frozen `family.relationship.change` P1 policy, if **END** removes a currently selected primary Family relationship and another same-Student, ACTIVE-Family, interval-valid alternative exists, the requester must **explicitly name the replacement**. The server must not guess.

The synthetic transaction seeds one Student with two open independent relationships in two distinct ACTIVE Families, one selected primary display context, and a third relationship for another Student. It retains independently authenticated same-school requester/reviewer Persons and the configured reviewer role. Suite20's 44 checks establish:

1. **Submission preflight:** omitted primary replacement, wrong-Student relationship and using the source as its own replacement are denied without any request, relationship or application. Explicit alternative is part of canonical intent: successful SUBMIT reaches PENDING version3; identical-key replay identifies the same request; a different replacement with the same key is denied.
2. **Independent review:** self-APPROVE and premature APPLY deny. The configured distinct Person approves with version4, but neither PENDING nor APPROVED changes a relationship, a selected primary context, or application history.
3. **Live stale-choice recheck:** after APPROVE, a transaction savepoint temporarily ends the selected alternative before the accepted effective date. Authenticated APPLY produces terminal INVALIDATED version5, leaves the selected source and primary context intact, and creates no successful application. The savepoint is rolled back for the independent valid-APPLY scenario.
4. **Successful explicit application:** requester APPLY produces EXECUTED version5 and returns retained source relationship identity; exact-key APPLY replay returns the same result. The source and previous primary context close at the exclusive effective boundary; exactly one appended open primary context points to the caller-selected other-Family relationship with `supersedes_id` referencing the predecessor. All original relationship rows remain, no child access appears, one application/effect event is recorded.
5. `SET CONSTRAINTS ALL IMMEDIATE` enforces deferred domain integrity. `ROLLBACK` leaves no synthetic fixtures behind.

## Limits / next gate

This is **test-only local D1C2A incremental coverage**, not general proof for all reviewer roles, multi-step policy shapes, runtime-loaded school data, other family mutation races or Family portal checked reads. No SQL draft, frozen Foundation, RLS/ACL, Flutter code or hosted environment was modified. **Migration 10 remains `.sql.draft`, full D1 and hosted deployment OPEN.**

**Checkpoint: `D1_EFFECT30_P1_PRIMARY_REPLACEMENT_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 6/6 RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.**
