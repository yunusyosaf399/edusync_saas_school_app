# Domain package 01 (D1A) — decision gate

**Status:** D1A product-question closure record. [Approved D1B0 decisions](DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md) resolve D1-01–D1-12; this table retains their original question and remaining implementation work. **0 D1B PRODUCT BLOCKERS REMAIN.** D1B physical design is permitted; SQL and migration 10 are not. The [specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) §§8–13, 19–21 remains the product baseline. The former subject/curriculum package ambiguity is resolved by D1-01: stable Subject identity now, curriculum later.

## Former D1B product blockers — all RESOLVED

| ID | Original question | Approved decision and remaining D1B/D1C detail |
|---|---|---|
| D1-01 | Which package owns subject identity versus curriculum? | **RESOLVED:** stable Subject catalog in D1; class/year curriculum, electives and assessments later. Design catalog identity/constraints now. |
| D1-02 | One or two class/level identities? | **RESOLVED:** one operational Class/Grade identity; stage/category optional metadata. Design catalog and optional classification. |
| D1-03 | Student ID owner, permanence and reuse? | **RESOLVED:** Student domain allocates permanent school-unique, non-reused ID at Student creation. Exact collision-safe allocator and formatting remain design work. |
| D1-04 | Admission number and sequence owner/time? | **RESOLVED:** Admissions allocates a separate permanent non-reused number at successful handoff; Student stores it. Design reservation/namespace/sequence mechanics preserving configured format and permanent uniqueness. |
| D1-05 | Roll modes and allocation policy? | **RESOLVED:** School Owner configures academic-context or persistent-student numeric roll; initial five-digit space/default `10000`, configurable start, audited manual adjustment. Design authoritative numeric namespace, collision/idempotency/concurrency and display derivation. |
| D1-06 | Class/section capacity and override? | **RESOLVED:** both class-offering and section capacities required; both enforced. Override needs explicit permission, reason, actor, audit and policy allowance, but no approval workflow solely for override. Design counted states and atomic enforcement. |
| D1-07 | Concurrent primary placements? | **RESOLVED:** at most one normal active PRIMARY enrollment per Student. End predecessor and create successor; special programs use separate assignments. Design temporal cardinality enforcement. |
| D1-08 | Student status meanings and reactivation? | **RESOLVED:** eight named states and transitions in [approved record](DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md); suspension may return, withdrawal/transfer may re-enroll, no normal reactivation from graduation/expulsion/death. Design transition/correction mechanics and placement consistency. |
| D1-09 | Multiple family links and history? | **RESOLVED:** multiple groupings allowed, one current primary display, effective relationship and access history separate; no adult Person or relationship automatically grants portal access. Design link/access cardinality and temporal checks. |
| D1-10 | Student field sensitivity? | **RESOLVED:** ROSTER, PROFILE, RESTRICTED IDENTITY, SENSITIVE/SPECIAL. Design field-limited read surfaces and permission/purpose checks. |
| D1-11 | Class/subject teacher granularity, overlap, substitution? | **RESOLVED:** one class teacher per section/time; section-specific subject teachers with PRIMARY, CO_TEACHER, SUBSTITUTE semantics; normally one active PRIMARY per subject+section; bounded substitutes. Design overlap/interval mechanics and eligibility checks. Elective groups later. |
| D1-12 | Department/designation depth? | **RESOLVED:** configurable catalogs plus effective-dated employment history in D1. Neither is an authorization role; compensation/contracts later. Design relations and history. |

## Can be deferred until D1C SQL, after D1B selects semantics

| ID | Acceptance gate |
|---|---|
| D1-13 | Exact relation/column names, `app` read projections versus `app_private`, FK/index/constraint and owner/privilege details. No broad client DML. |
| D1-14 | Exact concurrency mechanism for placement/capacity/roll/assignment overlap, idempotent reservation and conflict errors; D1B first fixes the business invariant. |
| D1-15 | Exact permission/operation codes, registered event types and redacted payload versions, audit target links and configurable approval chains. No untested handler activation. |
| D1-16 | Field lengths/formats, version metadata, index budget and effective-time representation. |
| D1-17 | Transition/correction mechanics and historical query projection after D1-08/D1-10 are accepted. |

## Can be deferred to later domain package or activation

| ID | Boundary |
|---|---|
| D1-18 | Admissions application, verification/test/interview, applicant identity and fee outcome. Preserve only an idempotent approved handoff; no Finance FK or early student creation. |
| D1-19 | Class/year curriculum and optional/elective selections if D1-01 selects A or C; assessment components always later. |
| D1-20 | Timetable, attendance session/capture, learning, exams/results and action-specific session rules; consume D1 history. |
| D1-21 | Payroll, salary/contracts, leave, medical, transport, hostel, library and Finance. Employee identity grants no payroll access. |
| D1-22 | Student photo, identity/birth/admission and employee document purpose activation. Purpose registry, entitlement snapshot, private adapter and handler must be approved together; this document authorizes no upload. |
| D1-23 | Offline sync protocol, AI/search/reporting projections and notification templates; current security/history contracts still bind later designs. |

**Count:** 0 D1B product blockers (12 resolved), 5 D1C physical choices, 6 later-package/activation choices. D1B still must design physical details and preserve approval/activation gates. New approved Emergency Contact and Employee Campus Affiliation are in the [decision record](DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md); they create no portal or authorization shortcut.
