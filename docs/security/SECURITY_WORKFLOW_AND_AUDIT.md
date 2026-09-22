# Security, Workflow and Audit Rules

## Security posture

Use least privilege, default-deny for sensitive data, and server-enforced authorization. Never trust the Flutter UI to enforce critical permissions by itself.

Never expose to Flutter:

- Supabase service-role key
- database password
- Supabase management token
- SMTP/app password
- AI provider secrets
- payment gateway secrets
- future device vendor secrets

## Permission model

A request should be evaluated against:

1. authenticated account
2. mapped person/business identity
3. active roles
4. action permission
5. scope/campus/class/section/subject ownership/assignment
6. target resource state
7. workflow restrictions

Examples of state restrictions:

- locked result cannot be edited directly
- finalized payroll cannot be edited directly
- verified financial records cannot be deleted
- historical attendance correction may require approval

## Sensitive domains

Highest sensitivity includes medical records, payroll, financial records, identity documents, audit data and administrative secrets.

Medical access should be stricter than ordinary student-profile visibility.

## Approval engine expectations

A change request needs enough information to be independently reviewed:

- request type
- target type and ID
- requester
- old value/state when applicable
- requested value/state
- reason
- evidence/attachments when applicable
- approval chain/step
- reviewer decision
- reviewer note
- timestamps
- application result/status

Approval chain is school-configurable. Example flows include Teacher -> Coordinator -> Principal, Teacher -> Principal, or direct/single-stage approval where school policy allows.

## Audit expectations

Audit important security and business events such as:

- authentication/admin account changes
- role/permission/scope changes
- student identity/status changes
- attendance corrections
- mark/result changes and publication
- fee/discount/payment/reversal operations
- payroll/salary changes
- approval decisions
- document access/deletion where appropriate
- AI administrative deletion/retention actions
- backup/restore/deployment operations

Audit must itself be access-controlled. Super Admin is not exempt from auditing.

## Deletion policy

- Financial history: reversal/cancellation, not normal hard delete.
- Published results: revision/correction, not destructive edit.
- Attendance history: correction trail.
- Audit: not deletable by normal role actions.
- AI conversations: admin may delete according to product policy, because these are not the same type of immutable business ledger.
- Uploaded documents: deletion rules depend on business/legal needs and should be audited where sensitive.

## AI security

AI queries must go through permission-aware services/views and must not receive broad raw database access. Treat prompt content as untrusted input. Log/monitor access appropriately without storing secrets in prompts.
