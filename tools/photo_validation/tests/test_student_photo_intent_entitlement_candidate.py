"""Synthetic trust-boundary tests only: NO real token or upload is issued."""
from dataclasses import replace
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from student_photo_intent_entitlement_candidate import (
    CAPABILITY, PURPOSE, ActorStudentEvidence, IssuedIntentEvidence,
    PhotoIntentDenied, SharedRevisionEvidence, SnapshotEvidence,
    check_photo_new_use_candidate,
)


def fixtures():
    snapshot = SnapshotEvidence(
        school_id="school-A", project_id="project-A", revision=7,
        signature_verified=True, issuer_and_key_verified=True,
        schema_verified=True, issued_at=100, effective_at=120,
        expires_at=600, upload_subscription_active=True,
        capabilities=frozenset({CAPABILITY}),
    )
    authority = SharedRevisionEvidence(
        school_id="school-A", project_id="project-A",
        active_revision=7, fresh_until=250, invalidated=False,
    )
    actor = ActorStudentEvidence(
        school_id="school-A", project_id="project-A",
        student_id="student-A", campus_id="campus-A",
        principal_id="staff-A", server_principal_verified=True,
        private_file_service=True, module_enabled=True,
        purpose_registry_approved=True, file_upload_granted=True,
        student_photo_submit_granted=True, student_scope_verified=True,
        student_ownership_verified=True,
    )
    intent = IssuedIntentEvidence(
        intent_id="trusted-record-A", school_id="school-A",
        project_id="project-A", student_id="student-A",
        campus_id="campus-A", principal_id="staff-A",
        purpose=PURPOSE, issued_revision=7, issued_at=150,
        expires_at=350, consumed=False,
    )
    return dict(snapshot=snapshot, authority=authority, actor=actor,
                intent=intent, now_epoch=200)


class PhotoIntentEntitlementPolicyCandidateTests(unittest.TestCase):
    def test_issue_and_finalize_happy_path_does_not_issue_any_token(self):
        base = fixtures()
        self.assertIsNone(check_photo_new_use_candidate(
            stage="ISSUE", snapshot=base["snapshot"],
            authority=base["authority"], actor=base["actor"],
            now_epoch=base["now_epoch"]))
        self.assertIsNone(check_photo_new_use_candidate(
            stage="FINALIZE", **base))

    def _denies(self, *, stage="ISSUE", **overrides):
        b = fixtures()
        b.update(overrides)
        if stage == "ISSUE":
            b.pop("intent")
        with self.assertRaisesRegex(
                PhotoIntentDenied, "^PHOTO_UPLOAD_INTENT_GATE_DENIED$"):
            check_photo_new_use_candidate(stage=stage, **b)

    def test_snapshot_attestation_and_subscription_fail_closed(self):
        b = fixtures()
        for field, bad in (
            ("signature_verified", False),
            ("issuer_and_key_verified", False),
            ("schema_verified", False),
            ("upload_subscription_active", False),
            ("capabilities", frozenset()),
            ("capabilities", frozenset({"storage.employee_photo.upload"})),
            ("signature_verified", "true"),
            ("capabilities", [CAPABILITY]),
            ("revision", True),
            ("issued_at", -1),
            ("issued_at", 201),
            ("effective_at", 201),
            ("expires_at", 200),
        ):
            with self.subTest(field=field, bad=bad):
                self._denies(snapshot=replace(b["snapshot"], **{field: bad}))

    def test_shared_revision_freshness_and_invalidation_fail_closed(self):
        b = fixtures()
        for field, bad in (
            ("active_revision", 6), ("active_revision", 8),
            ("active_revision", True), ("fresh_until", 200),
            ("fresh_until", 199), ("invalidated", True),
            ("invalidated", "false"), ("school_id", "school-B"),
            ("project_id", "project-B"),
        ):
            with self.subTest(field=field, bad=bad):
                self._denies(authority=replace(b["authority"], **{field: bad}))

    def test_actor_scope_domain_and_private_service_fail_closed(self):
        b = fixtures()
        for field in (
            "server_principal_verified", "private_file_service",
            "module_enabled", "purpose_registry_approved",
            "file_upload_granted", "student_photo_submit_granted",
            "student_scope_verified", "student_ownership_verified",
        ):
            with self.subTest(field=field):
                self._denies(actor=replace(b["actor"], **{field: False}))
        for field in ("school_id", "project_id"):
            with self.subTest(field=field):
                self._denies(actor=replace(b["actor"], **{field: "other"}))
        self._denies(actor=replace(b["actor"], student_ownership_verified="true"))
        self._denies(actor=replace(b["actor"], student_id=""))
        self._denies(actor=replace(b["actor"], principal_id=" staff-A"))

    def test_finalization_requires_exact_trusted_unconsumed_intent(self):
        b = fixtures()
        for field, bad in (
            ("school_id", "school-B"), ("project_id", "project-B"),
            ("student_id", "student-B"), ("campus_id", "campus-B"),
            ("principal_id", "staff-B"), ("purpose", "BIRTH_CERTIFICATE"),
            ("issued_revision", 8), ("issued_revision", 0),
            ("issued_revision", True), ("issued_at", 201),
            ("expires_at", 200), ("consumed", True),
            ("consumed", "false"), ("intent_id", ""),
        ):
            with self.subTest(field=field, bad=bad):
                self._denies(stage="FINALIZE", intent=replace(b["intent"],
                                                             **{field: bad}))
        self._denies(stage="FINALIZE", intent=None)

    def test_current_downgrade_suspension_scope_change_blocks_finalize(self):
        b = fixtures()
        # An old valid intent cannot bypass a current downgraded subscription.
        self._denies(stage="FINALIZE", snapshot=replace(
            b["snapshot"], capabilities=frozenset()))
        self._denies(stage="FINALIZE", snapshot=replace(
            b["snapshot"], upload_subscription_active=False))
        self._denies(stage="FINALIZE", actor=replace(
            b["actor"], student_photo_submit_granted=False))
        self._denies(stage="FINALIZE", actor=replace(
            b["actor"], student_scope_verified=False))
        self._denies(stage="FINALIZE", authority=replace(
            b["authority"], invalidated=True))

    def test_new_approved_revision_may_finish_old_intent_only_if_still_entitled(self):
        b = fixtures()
        advanced = replace(b["snapshot"], revision=8)
        shared = replace(b["authority"], active_revision=8)
        self.assertIsNone(check_photo_new_use_candidate(
            stage="FINALIZE", snapshot=advanced, authority=shared,
            actor=b["actor"], intent=b["intent"], now_epoch=200))
        self._denies(stage="FINALIZE", snapshot=replace(
            advanced, capabilities=frozenset()), authority=shared)

    def test_expired_and_future_snapshot_and_intent_are_not_authority(self):
        b = fixtures()
        self._denies(now_epoch=600)
        self._denies(now_epoch=110)
        self._denies(now_epoch=250)
        self._denies(stage="FINALIZE", now_epoch=350)
        self._denies(now_epoch=True)
        self._denies(stage="FINALIZE", now_epoch=-1)

    def test_stages_and_client_issued_intent_not_accepted_for_issue(self):
        b = fixtures()
        self._denies(stage="APPROVE")
        with self.assertRaises(PhotoIntentDenied):
            check_photo_new_use_candidate(stage="ISSUE", **b)
        self._denies(snapshot={"pretend": "signed"})
        self._denies(stage="FINALIZE", intent={"pretend": "trusted"})


if __name__ == "__main__":
    unittest.main()
