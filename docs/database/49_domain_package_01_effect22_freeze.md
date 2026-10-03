# D1C1B Effect 22/36 — Student Special freeze

**Status: FROZEN.**

- Effect: **22/36**
- Operation: `student.special.correct`
- Required review permission: `student.special.approve`
- Trusted runtime SHA: `ff9abc0667f89eefd0225c2a51f7495cd8c36968`
- Exact-SHA GitHub Actions run: **#61** (`37108384161`)
- CI result: PASS
- Tooling tests: **121/121**
- Foundation pgTAP: **220/220**

## Frozen semantics

1. CORRECT-only; an effective source special snapshot must already exist.
2. Nullable disability/orphan indicators preserve unknown as distinct from false.
3. Blood group is NULL or one of: `A_POSITIVE`, `A_NEGATIVE`, `B_POSITIVE`, `B_NEGATIVE`, `AB_POSITIVE`, `AB_NEGATIVE`, `O_POSITIVE`, `O_NEGATIVE`.
4. Exact factual no-op is rejected; reason-only change creates no successor.
5. Accepted correction closes the exact current source and appends one successor at the same server apply timestamp with `supersedes_id=source_snapshot_id`.
6. P2 review is always required; no DIRECT route.
7. Requester and reviewer must be different People.
8. Student ACS authorization is ALL/CAMPUS/CLASS/SECTION through current PRIMARY placement ancestry; placement existence itself grants nothing.
9. Review/apply recheck live requester and exact reviewer role/scope authority, policy, Student version, source snapshot/facts, and placement ancestry.
10. Deterministic stale business/authority conditions cause `APPROVED -> INVALIDATED`; malformed protected workflow data rolls back.
11. Terminal apply replay returns durable terminal result without duplicate mutation/evidence and still requires current requester or exact final-approver authority.
12. Broad audit/outbox excludes disability indicator, orphan indicator, blood group, and arbitrary reason text.
13. Event is `student.special_corrected`; aggregate is resulting `STUDENT_SPECIAL` snapshot, version 1.
14. Successful application row is guarded by exact receipt/request/target/predecessor/successor/lineage/timestamp binding.

The independent audit correction at the trusted runtime SHA strengthened application binding so reviewed facts cannot diverge from the recorded predecessor/successor while still producing a successful application.

Migration 10 remains non-executable `.sql.draft`. D1C2, remote deployment, and staging execution remain unauthorized.