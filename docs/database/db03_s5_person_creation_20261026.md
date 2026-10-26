# DB03 S5 — checked, school-wide Person creation

**Implementation candidate, 26 October 2026.** The owner chose qualified school-wide identity staff with explicit permission to create Person records, and **stop for review** when possible matches exist. No documented override or automatic merge is selected. The repeated prompt received real answers; the earlier aborted prompt did not. [Exact decision record](db03_owner_decisions_person_creation_20261026.json).

This implements real Foundation Person insertion and S4 original-birth-document inspection/binding for an unresolved application. It does not create a Principal, Auth account, Student or enrollment, issue a number, submit an application, or waive document/Finance gates. Inactive proposals remain outside executable migrations; no registration, hosted write or merge is authorized.

## Two fixed APIs

| Command | Exact operation and permission | Result |
|---|---|---|
| `app.check_admission_person_candidates(application_id uuid, expected_application_version bigint, display_name text, key text)` | `admission.person.check` | immutable check ID, full candidate count and up to 50 private candidate snapshots |
| `app.create_admission_person(application_id uuid, expected_application_version bigint, check_id uuid, original_reference text, reason text, key text)` | `admission.person.create` | one new Person, source inspection, bound DRAFT and immutable creation record |

Both require a genuine current active INDIVIDUAL, exact enabled operation/handler and version-1 contract/payload, non-family-safe permission, complete effective role/grant/assignment/scope chain, and **ALL/DIRECT**. An assigned-Campus grant is insufficient even for an application in that Campus. Configured approval fails closed; no seed or permission assignment is supplied. Private actor/evidence helpers retain dedicated roles; public fixed definer wrappers use the existing NOLOGIN identity executor. All search paths and client revocations are explicit. No generic user JSON command exists.

The check is bound to one actor, unbound DRAFT, reviewed application version and proposed name. Creation needs that same actor/check/application/version, zero flagged candidates, unchanged Person catalog, original inspection reference and private reason. The display name comes from the retained check, not a second caller-controlled name. The root stays DRAFT, Person is server-generated, and the source uses the previously selected `ORIGINAL_BIRTH_CERTIFICATE_INSPECTION` method. Creation advances root version and evidence epoch and writes the S4 source history atomically. A staff attestation is accountable human evidence, not a government verification or proof that software physically saw a paper original.

## Screening, privacy and possible matches

The engineering screening rule (version 1) uses Unicode NFKC, C-collation lowercasing, whitespace/punctuation folding, and either equal normalized full names or any equal token of at least two characters. It considers ACTIVE, INACTIVE and ARCHIVED People across the school. It deliberately flags shared-name candidates; **names are not identity proof**, and candidates are never auto-merged. Non-ASCII case folding, transliteration, alternate spellings and aliases are not exhaustively resolved by this heuristic. Qualified staff must inspect originals and existing institutional records; zero candidates is not a guarantee that no real-world duplicate exists. No DOB/national-ID matching index or new sensitive identity attributes are invented.

If matches are flagged, creation stops before inserting a Person or changing the application. Staff can use the separately authorized S4 existing-Person inspection if the match is genuinely the same child. A similar-named but different child remains blocked until an explicitly approved disambiguation route is added; this increment supplies **no override**. Archived records cannot be used as a reason to manufacture another identity.

The private check record retains the requested name, normalization version, full catalog fingerprint, full candidate count and at most 50 server-generated candidate snapshots (ID, display name, version, state). JSON here is a bounded private **read snapshot**, not caller-supplied authority. Core identity and effect links remain real typed FKs. Snapshot names reflect the historical lookup and may become stale; matching retry reauthorizes and returns the original snapshot without refreshing it. There is no raw client Person/history SELECT. Names, candidate details, original references and reasons stay out of broad receipts/audit/outbox. No arbitrary retention period or automatic deletion policy is invented.

## Freshness and lock protocol

A new additive BEFORE STATEMENT trigger on Foundation People INSERT/UPDATE/DELETE/TRUNCATE takes the existing EXCLUSIVE authorization fence `(71001,1)` before row locks. Check/create acquire that same EXCLUSIVE fence **from the start**, then actor/operation/key, School, Campus, Year and application locks. This makes the catalog stable through checking/creation and avoids shared-to-exclusive upgrades inside these commands. Person insertion and subsequent binding occur within this exclusive section. Existing S2–S4 shared readers serialize with Person changes; their complete regression/races rerun with this trigger installed. Frozen Foundation files/functions are not rewritten.

The catalog fingerprint covers every Person's ID, state, row version and display name, in sorted ID order. **Any** intervening Person change invalidates a check, including an unrelated rename or archive; a fresh key/check is required. Current authorization and exact destination/root conditions are rechecked after waits. Two applications with previously empty checks for the same name cannot both create under those snapshots: the first changes the catalog; the second must recheck, where the new possible match is flagged.

The global exclusive fence and full-catalog scan are conservative initial engineering choices. They trade throughput for serializable freshness without inventing an identity identifier. This is not a complete D1/Finance/file lock-graph or populated-scale acceptance claim. All future Person writers and composition must retain a compatible authorization-first protocol; performance/contention and recovery require release validation.

## Durable sources, atomicity and replay

Two new private immutable histories record candidate checks (#19) and Person creations (#20). Creation references the exact check, real Person, application and S4 inspection. One check/application/Person/resolution can have only one creation effect. RLS is forced; normal client/raw owner DML and DELETE/TRUNCATE are denied. No reverse application-to-creation/source pointer is added.

Check writes one receipt/audit/outbox without advancing or binding the application. Creation atomically commits Person, root version/epoch, original inspection, creation source, receipt and minimized audit/outbox; all deferred receipt FKs must resolve at commit. Event failure leaves none of those mutation effects. Evidence writing remains in the dedicated evidence role. New creation proof recomputes the pre-insertion catalog excluding exactly the newly created Person and checks the new Person's original name, creator and version.

Canonicalization version 1 uses a fixed JCS array of application/version/check strings and SHA-256 digests of supplied private name/reference/reason. Check result has three safe receipt keys (check/application ID and count); creation result has five (creation/application/version/Person/resolution IDs). Broad check event contains check/application ID only; creation event contains creation/application ID and version. Historical successful creation retries retain the original Person and source even after Person edits/withdrawal; they neither create again, reactivate a Person nor reopen an application. Current revocation blocks replay. Changed intent conflicts.

## Validation and remaining work

Fifty new pgTAP assertions cover ALL versus Campus authority, disabled defaults, private ACLs, typed input, normalization, bounded candidates, zero-match check, possible-match blocking, archived matches, stale catalog rejection, application/check binding, immutable histories, safe retries, actual Foundation insertion without login/Principal creation, original-inspection/source binding, output-failure atomicity and retained withdrawal. Five actual backend schedules observe the blocker before release: same-key replay; same-name creation from two old checks; Person writer before creator; creator before Person writer; and revocation before creation. Durable People count, root version/epoch and creation history are checked independently.

The previous 200 DB03 assertions, fifteen races and 220 frozen Foundation assertions rerun with S5 installed. Failure-injected installation rollback checks new tables/APIs/catalog fence are absent. Fixtures roll back; race records live only in a separately reset disposable database; the stack stops. Exact-head results are recorded in PR #102 after observed CI execution, not inferred from prepared tests.

Remaining: ambiguous-name disambiguation/merge/correction and broader checked discovery; certificate private upload/entitlement/purpose/retention and independent reviewer integration; trusted transfer classification; composed D1 destination; submission/numbering; final Finance/READY/Student handoff; populated upgrade/recovery/security/performance/release acceptance. The two-month certificate window and different-uploader/verifier choice are unchanged.

**Example:** a qualified registrar checks the proposed child against existing records. If no possible match is flagged and the catalog is still unchanged, the registrar records inspection of the original birth certificate and creates/binds one Person. If “Ali Khan” appears as a possible match, creation stops for review; the system neither merges the children nor invents a second identity.

Technical normalization reference: [PostgreSQL 17 string functions](https://www.postgresql.org/docs/17/functions-string.html).
