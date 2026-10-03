# D1C1B Effect 20 security refreeze — employee experience

**Status: FROZEN security review.** Trusted implementation SHA: `91e05dc0eef35144f1b0e37263ed50703b83756d`.

Effect 20 adds no new permission, scope alternative, role, operation contract, or event vocabulary. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

`employee.experience.change` and `employee.experience.approve` use the frozen Employee-action authorization family with complete current grant chains over ALL or matching CAMPUS scope. Multiple current Employee campuses must all be covered, and their active P1 policies must converge on one route. APPROVAL routing must converge on one policy identity. A zero-campus Employee requires ALL authority plus the school policy.

Requester/reviewer Person separation is preserved. Reviewer selection requires the configured reviewer role and matching approval authority. Review and apply recheck current policy and authority, and apply revalidates completed approval steps. Deterministic stale-policy, stale-authority, or domain-preflight failures invalidate the approved request without mutation. Malformed stored workflow payloads and transient/unclassified failures rollback. Successful replay uses durable result evidence and does not duplicate the mutation or event.

Organization name, role title, optional summary, and arbitrary reason are excluded from broad audit/outbox evidence. Typed request reads remain participant-limited. Authenticated clients receive only effect-specific checked RPC execution; no direct authenticated base-table write is added.

The independent audit of initial candidate `5b2375219ae1120767eb3617a6fefde2c853061e` found one fixed-shape defect: DIRECT/SUBMIT canonical intent was validated as 10 fields while the command contains 11. Corrected SHA `91e05dc0eef35144f1b0e37263ed50703b83756d` changes only that arity contract. Exact-SHA workflow #48 (`37093252954`) then passed 121/121 tooling tests and 220/220 Foundation assertions.

Migration 10 remains draft and non-executable. D1C2 and remote/staging application remain unauthorized.
