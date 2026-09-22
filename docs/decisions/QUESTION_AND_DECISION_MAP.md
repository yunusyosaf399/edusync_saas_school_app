# Question and Decision Map

This is a compact map of the product-discovery questions that produced the current architecture. The detailed wording and answers remain in `School_OS_SaaS_Master_Specification_v0.2.md`, especially Sections 73-75.

## Initial product questions

### Institution and academic structure

**Questions:** school/college scope, configurable grades, academic years, multiple campuses.  
**Decision:** current product targets schools from Play Group/Nursery through Grade 12 with fully configurable levels. A school may omit Play Group or use its own structure. Multiple campuses are supported. Historical academic years are retained.

### Users and roles

**Questions:** who logs in, what can each role do, whether roles need custom permissions.  
**Decision:** broad school roles are supported, but authorization is not hard-coded solely by role. Use granular permissions, scope and approval authority.

### Students and family

**Questions:** student fields, statuses, multiple children per parent, teachers who are also parents.  
**Decision:** student profile is rich but should be relational. Families can link multiple students. One person/account may hold multiple roles. Student status history and enrollment history are required.

### Admissions

**Questions:** application -> verification -> test -> interview -> approval -> fee -> enrollment -> class allocation.  
**Decision:** configurable staged admission workflow; stages may be skipped. Generate school-facing numbers/documents dynamically.

### Classes/sections/promotion

**Questions:** sections, room/capacity, automatic promotion, failed/repeat/manual cases.  
**Decision:** classes/sections are configurable. Promotion creates a new enrollment record and preserves history.

### Curriculum

**Questions:** fixed curriculum vs user-created, compulsory/optional/elective.  
**Decision:** curriculum is school-configurable; students may have individual optional/elective choices.

### Teachers

**Questions:** teacher profile, dashboard, class/subject assignments.  
**Decision:** full employee/teacher profile; teachers can span multiple subjects/classes/sections/campuses; assignment context controls access.

### Attendance

**Questions:** daily/subject/period attendance, late/leave/reporting, manual/QR/biometric future.  
**Decision:** current operational truth is primarily morning/first-class attendance with optional post-break session. Manual and QR are initial capture methods. Corrections require approval. The architecture must support future biometric/camera/RFID/NFC adapters without redesigning canonical attendance.

### Timetable

**Questions:** conflict prevention and generation.  
**Decision:** prevent teacher/room/class conflicts; support automatic generation and manual adjustment.

### Homework/learning

**Questions:** homework, projects, worksheets, quizzes, submissions, feedback.  
**Decision:** support full learning-work lifecycle with student and parent visibility.

### Exams/results

**Questions:** custom exam types, subject mark components, grades/GPA/ranking, result PDF.  
**Decision:** flexible assessment engine. Exam Controller reviews/publishes. Published results lock; corrections use revision workflows.

### Finance

**Questions:** fee types/frequencies, discounts, bank/wallet proof, partial/advance, overpayment, overdue, invoice/receipt storage.  
**Decision:** configurable finance engine with ledger-like integrity. Financial facts persist; generated PDFs are on demand. Parent payment proof requires verification. No normal hard deletion of transactions.

### Portals/communication

**Questions:** parent/student dashboards, notifications, messaging.  
**Decision:** role-specific portals. In-app/push/email initially; WhatsApp later. Search and communication are permission-aware.

### Library/transport/hostel/medical

**Decision:** supported as modular domains. GPS is future. Medical has stricter access.

### HR/payroll/leave

**Decision:** full HR/employee management, monthly payroll, configurable salary increments/manual changes, bonus/overtime/deductions, configurable leave approvals.

### Documents

**Decision:** source uploads go to private Storage, target <=1 MB. Generated PDFs normally are not stored automatically.

### AI

**Decision:** teacher/student/parent/principal AI features are planned. AI must respect normal authorization and cannot become a permission bypass.

### Offline

**Decision:** required, especially for attendance. Local sensitive data is encrypted; important conflicts are explicitly resolved.

---

## Deep architecture questions Q50-Q100

### Q50-Q53 - authentication, multiple roles and parent login

- Login: email or admin-created username; retain school-generated IDs as metadata/identifiers.
- One account may have multiple roles, e.g. teacher + parent.
- Family currently uses a shared parent/guardian login acting as one family role for linked children.

### Q54-Q57 - permissions and teaching scope

- Separate action permission from data scope.
- Teacher access is not automatically school-wide.
- Different sections can have different subject teachers.
- One section has a class teacher and multiple subject teachers.

### Q58-Q66 - academic years, history, numbering, capacity and promotion

- Academic-year dates are configurable; history remains available.
- Important profile/status history is retained.
- Admission number format is school configurable.
- Roll numbering supports default or custom starting sequences.
- Capacity should be enforced with authorized override if designed.
- Promotion is a lifecycle process that creates new enrollment history.

### Q67-Q72 - subjects/exams/publication

- Subject structures are configurable by class/year/student choice.
- Unlimited/custom exams are supported.
- Reusable templates are supported.
- Exam Controller is the publication gate after review.

### Q73-Q77 - invoice/payment records

- Invoice PDF is not stored, but the underlying financial record and invoice number are persistent.
- Verified payment gets a permanent receipt number.
- Payment evidence can be approved/rejected/corrected.
- Duplicate transaction evidence should be detected.

### Q78-Q80 - payroll/leave

- Payroll is monthly and locked after finalization.
- Salary change/increment may be configured automatically or manually rather than assuming one fixed salary-history rule.
- Leave approval hierarchy is school-configurable.

### Q81-Q88 - storage, notifications, offline, backup

- Compress/validate uploads to <=1 MB target.
- Structured Storage paths/buckets.
- Immediate/scheduled/event notifications.
- Email initially can use app-password style configuration but should be provider-abstracted.
- Offline conflict detection is preferred over silent overwrite.
- Local offline data is encrypted.
- Need database/configuration/deployment backup strategies.

### Q89 - SaaS architecture evolution

The discussion temporarily considered a shared multi-school database. Final decision later changed to **Option A: one Supabase project per customer school** under a SaaS operation. This final choice supersedes earlier multi-tenant-table ideas.

### Q90-Q94 - AI/search/audit/delete policy

- AI and global search obey normal permissions.
- AI conversation history can be stored and administratively deleted according to policy.
- Audit is access-controlled.
- Financial/results/attendance/audit histories use correction/reversal/history patterns rather than ordinary hard delete.

### Q95-Q100 - senior roles, languages, product philosophy

- Owner/Super Admin/Principal capabilities are permission-configurable, not assumed solely by title.
- Super Admin is audited.
- English initially, architecture should allow localization later.
- Product philosophy selected: **Modern School Operating System** using the five core engines.

---

## Final SaaS decision after Q100

The selected architecture is:

```text
SaaS operator
  -> Supabase Organization
      -> Control Plane Project
      -> School A Project
      -> School B Project
      -> School C Project
```

Each school project contains that school's Auth/Postgres/Storage/functions/policies. The application code and migration set are reusable. The school user should not need direct Supabase access for normal operations.

This final SaaS decision is the starting assumption for database design.
