# Future Architecture Roadmap

The 2026-10-05 database-first instruction brings the defined future **database designs** into current scope; track them in the [database completion matrix](../database/DATABASE_COMPLETION_MATRIX.md). Hardware, vendor adapters and application services remain later implementation. Complete the data contracts without inventing unresolved privacy, retention or provider choices.

## 1. Attendance hardware ecosystem

### Fingerprint / biometric terminals

Future requirement. Likely integration through vendor/device adapters. The canonical attendance service should accept validated identity/time events without depending on the vendor schema.

Do not decide now where biometric templates live. That requires a separate privacy, legal, retention and security design.

### Camera / face-recognition attendance

Future high-complexity feature. Possible architecture:

`camera/edge device -> recognition/anti-spoof service -> confidence + identity event -> validation policy -> attendance service`

Potential requirements later:

- device registry
- camera location/campus mapping
- consent/legal policy
- retention policy for images/video
- face-template/model governance
- false positive/negative handling
- anti-spoofing
- human override/review
- confidence thresholds
- audit of automated attendance decisions

None of these should be implemented simply by adding a `face_vector` column to students.

### RFID / NFC

Future medium-complexity feature. Student card/token mapping should be separable from student identity so cards can be issued/replaced/revoked.

### Advanced QR anti-fraud

Possible future improvements: rotating/signed tokens, device confirmation, photo confirmation, token expiry/versioning.

## 2. Transport GPS

Keep vehicle/route/student-assignment core independent from GPS provider. Future telemetry should be provider-adapted and not required for basic transport operations.

## 3. Messaging channels

Notification engine should have channel/provider abstraction so WhatsApp or other future channels do not require changing domain events.

## 4. Payment gateways

Payment ledger/evidence model should accept future gateway webhook confirmations using idempotency and provider transaction references. Do not model today's bank screenshot workflow in a way that prevents automated payment confirmation later.

## 5. Inventory/assets

Large optional future domain covering procurement, assets, assignments, location, maintenance and disposal. Keep it modular rather than adding asset columns to unrelated tables.

## 6. IoT/smart classroom/CCTV

Treat as external device/event domains. Use device registry/integration adapters where necessary. CCTV integrations introduce substantial privacy/security requirements and should not be mixed into ordinary school records.

## 7. Government/accounting integrations

Prefer canonical internal models plus mapping/export/integration adapters. Do not reshape core student/finance data around a single external government's or accountant's schema.

## 8. Localization

English initially. Keep UI strings localizable and avoid using translated display text as database identifiers. Future Arabic/Urdu may require RTL layouts.

## 9. AI evolution

Future possibilities include voice interfaces, advanced tutoring, teaching-plan generation, predictive analytics and early-warning models. Preserve clean historical data and explicit authorization; do not make AI model output the authoritative business record without review/workflow where needed.

## 10. Certificate verification

Stable certificate/document identifiers can support future verification mechanisms. Blockchain is only one possible implementation and should not be assumed now.

## Client targets and hardware capability boundaries

Android, Windows and Web are current first-class targets of one Flutter codebase, not deferred roadmap features; see [client architecture](03_flutter_multiplatform_architecture.md). Future hardware remains deferred and may require a selected platform or edge/local gateway. A Windows gateway may communicate with a terminal while Web consumes authorized canonical attendance results. Do not require every client to implement every hardware protocol or duplicate attendance truth.
