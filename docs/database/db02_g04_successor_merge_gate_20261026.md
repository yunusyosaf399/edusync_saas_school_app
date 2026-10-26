# DB02 G04 — reviewed successor integration

The owner's instruction to complete the next task after G03 authorizes G04 repository integration. The target is the dedicated `integration/db02-reviewed-successor-20261026` branch, created at DB02 #101 design SHA `1cf6aa51827000c77f17c7489be8b4fc18aebc97`. Main/hosted deployment remains outside this operation. A merge commit must preserve original histories and have the exact tested candidate tree.

The accepted DB02 implementation is #168 `f472f2abf3303ffef10d4744a4dd6af5735acc5e`. The acceptance/policy head `9dd47dcdcf2843c59f8d162e9991c66dad08f1e7` adds only seven policy/review documentation paths. Its first G04 candidate, PR #171, passed static/Foundation but failed runtime #40265466506 in the successive DB01 date fixture at `D1_DB01_P1_APPLY_RACE_NEXT_SCHOOL_DAY_NOT_LATER` on 26 October, 03:50 UTC.

## Fixture repair and focused review

The fixture assumed UTC → Pacific/Kiritimati always advances a calendar date; before 10:00 UTC both dates can be equal. Its stored School timezone now starts at `Etc/GMT+10` (UTC-10), then moves to Pacific/Kiritimati (UTC+14), producing consecutive dates at every UTC hour. Initial admission/status/capacity/placement facts use two UTC dates ago so R0 predates even the western School day. The date replacement matches the exact `CURRENT_DATE-1` expression; it preserves distinct offsets such as `CURRENT_DATE-180`. Genuine protected P0, SUBMIT, independent REVIEW and APPLY still generate all tested Roll/approval evidence; no Enrollment/Roll is inserted directly by the repair.

Only the successive test opts into the fixture transformation; the common fixture and other race cases retain their behavior. Four focused tests reproduce the original 03:50 UTC failure, verify all 1,440 minutes on an ordinary date, year end and leap day, preserve genuine commands and other date offsets, and fail on fixture drift. All 396 local tooling tests pass. The 291-fragment SQL digest, 112-suite registry / 4,292 SQL assertions, public endpoints, grants, catalog and production date logic are unchanged. G02 composition source gates continue to pass.

This fixture repair is necessary to make the authorized integration validation reliable; it changes no accepted business rule or hosted database. The final candidate requires all three checks at its exact SHA before merge. Record actual PR, tested head, run links, merge result/parents/tree and owner-input ancestry in the PR and issue #69 after execution. Do not count the failed #171 runtime as acceptance or hide it by weakening assertions.

G04's integration successor is the accepted source baseline for G05's final contract freeze. G06 still requires its separate release authorization and hosted upgrade/rollback/permissions acceptance. DB01 installed DB03/DB04 handoffs and its other release gates remain separate.
