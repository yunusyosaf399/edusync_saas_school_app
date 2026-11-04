# DB03 S7 — PDF certificate uploads

Owner instruction, 27 October 2026: “Certificate in pdf can also be supported”. This extends the accepted S7 private certificate collection candidate. PNG and JPEG continue to work. No executable migration, hosted database, deployment entitlement or permission activation is introduced.

## Accepted input

The upload service derives MIME from actual validated bytes. PDF certificates may contain 1–50 pages and up to 1,048,576 bytes inclusive, sharing the existing limit with images. Both the upload-intent SQL constraint and private allocator allow `application/pdf`. The stored metadata uses the measured original byte count and SHA-256. The private archive retains the exact original PDF, including any signature bytes; the validator neither rewrites nor certifies digital signatures.

`measure_certificate()` dispatches PDFs to a separate Python subprocess with isolated import paths using pinned `pypdf==6.21.2`. Strict parsing checks the PDF header/EOF, cross references, page tree, finite page geometry, page-content syntax and reachable document objects/streams. Encrypted PDFs are rejected even with an empty password. JavaScript/actions, external stream references, embedded/associated files, XFA and rich media are rejected, including indirectly referenced action selectors. These are content-policy and format checks, not certificate authenticity or exhaustive malware detection.

The parser process has a five-second parent deadline, three CPU seconds, 256 MiB address-space limit, no core/file output and a bounded descriptor count. Input is bounded before subprocess creation; document traversal is limited to 10,000 object visits, decoded streams to 32 MiB total, page content to 100,000 operations per page, page dimensions to 14,400 points per axis and embedded images to 20 million pixels. Unsupported process-limit facilities, parser errors, repairs/warnings, crashes and timeouts fail closed. Private bytes pass through stdin; parser output is discarded and no temporary PDF is written. Runtime deployment remains on the same POSIX backend assumed by the private archive adapter.

## Unchanged admission gates

Validating PDF format is not the principal's document verification. An administrator still needs current scope and permissions; upload still requires current signed school entitlement/module, a current application-bound intent, sealed private storage and post-storage validation. The server revalidates the actual stored PDF before making metadata AVAILABLE. Receipt, attachment, idempotency, forwarding, permanent retention, withdrawal and quarantine behavior are shared with images. Missing required documents still block forwarding, and forwarding creates no Student or submitted application.

## Validation

Seventeen additional local unit cases bring the service suite to 42: valid/multipage PDF and unchanged original hash; invalid envelope/truncation; encryption including empty password; no/excessive pages; JavaScript; embedded files; XFA; excessive decompression; external streams and indirectly selected external actions; malformed page content; inclusive 1 MiB boundary; parser timeout and process crash. The existing 25 image/entitlement/archive cases remain.

The disposable integration runner uploads an actual two-page PDF through current Auth, signed entitlement, real restricted worker login and the private archive; checks PDF MIME/size/hash and exact stored bytes; retries the same upload; forwards it to the principal queue; and proves unsafe PDFs create no upload intent. The existing same-key forwarding race now uses a real PDF attachment. All 305 DB03 pgTAP assertions, 220 frozen Foundation assertions, retained service cases and 29 PostgreSQL concurrency schedules rerun. Exact runtime results are recorded in PR #102 after observed execution; prepared cases alone do not constitute a pass.

Original S7 baseline: tested head `ba2f07fb23f1c365b84e2c34ee746009ecf0eec1`, [DB03 run 40380095994](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40380095994), 305 DB03 / 220 Foundation / 25 service unit / 45 integration assertions / 29 concurrency schedules. The PDF successor must use its own tested source, not borrow that baseline as PDF acceptance.

Primary parser references: [strict parsing](https://pypdf.readthedocs.io/en/stable/user/robustness.html), [PdfReader](https://pypdf.readthedocs.io/en/stable/modules/PdfReader.html), [security limits](https://pypdf.readthedocs.io/en/stable/user/security.html).
