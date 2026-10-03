# D1C1B Effect 22/36 — Student Special security review

**Status: POST-CI SECURITY REVIEW — PASS.**

Effect 22 adds no permission, scope alternative, role, operation contract, or event vocabulary. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

`student.special.correct` and `student.special.approve` use the frozen non-family-safe Student ACS scope family. Current PRIMARY placement supplies target ancestry only; assignment existence alone grants nothing. The exact permission must be backed by a live principal, role assignment, grant, scope contract, and matching ALL/CAMPUS/CLASS/SECTION scope.

P2 review is mandatory. Requester/reviewer separation is enforced at Person level. Review and apply recheck current exact reviewer role/scope authority and current requester authority. Deterministic stale policy, authority, Student version, source snapshot/facts, placement ancestry, or no-op state invalidates an approved request; malformed protected request/workflow data is not converted into a business invalidation.

Broad evidence excludes all raw special values and arbitrary reason text. `student.special_corrected` publishes only safe identifiers and effective time. The resulting special snapshot is the retained-history aggregate (`STUDENT_SPECIAL`, version 1); Student version remains the concurrency/application target version.

No authenticated direct DML to `app_private.student_special_details` is introduced. Migration 10 remains `.sql.draft`; no D1C2, remote, or staging execution is authorized.