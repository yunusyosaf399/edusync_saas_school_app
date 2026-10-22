"""Synthetic, offline photo bucket and server-secret *checklist* preflight.

No live provider mutation, secret material, School user fixtures, or real upload.
"""
from dataclasses import replace
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from student_photo_supabase_bucket_preflight_candidate import (
    BucketObservation, StorageObservation, CustodyChecklist,
    PhotoPreflightDenied, inspect_offline_private_photo_setup,
    approve_live_setup,
)
from student_photo_supabase_storage_adapter_candidate import (
    PROPOSED_BUCKET, LIMIT_BYTES, PrivateBucketProposal,
)


class SupabasePhotoPrivatePreflightTests(unittest.TestCase):
    def setUp(self):
        self.custody = CustodyChecklist()
        self.observed = StorageObservation(
            region="us-east-1", project_status="ACTIVE_HEALTHY",
            buckets=(), objects_rls=True, buckets_rls=True,
            object_policy_count=0, bucket_policy_count=0,
        )
        self.photo_bucket = BucketObservation(
            name=PROPOSED_BUCKET, public=False, file_size_limit=LIMIT_BYTES,
            allowed_mime_types=("image/png","image/jpeg"),
        )

    def run_preflight(self, **kwargs):
        return inspect_offline_private_photo_setup(
            observed=kwargs.get("observed",self.observed),
            custody=kwargs.get("custody",self.custody),
            proposal=kwargs.get("proposal",PrivateBucketProposal()),
        )

    def test_current_empty_sandbox_remains_not_provisioned(self):
        outcome=self.run_preflight()
        self.assertEqual(outcome.bucket_state,"NOT_PROVISIONED")
        self.assertEqual(outcome.credential_state,"REVIEW_OPEN")
        self.assertEqual(outcome.runtime_photo_upload,"DENY")

    def test_matching_private_bucket_is_only_config_matching(self):
        observed=replace(self.observed,buckets=(self.photo_bucket,))
        outcome=self.run_preflight(observed=observed)
        self.assertEqual(outcome.bucket_state,"CONFIG_MATCH_ONLY_NOT_AUTHORIZED")
        self.assertEqual(outcome.runtime_photo_upload,"DENY")

    def test_even_all_paper_credential_checks_cannot_authorize_upload(self):
        declared=CustodyChecklist(
            backend_only=True, secret_manager=True,
            never_flutter_or_browser=True, never_logged_or_in_repo=True,
            secret_rotation_owner_assigned=True,
            incident_revoke_process_reviewed=True,
            current_student_scope_resolver_integrated=True,
            independent_security_review_recorded=True,
        )
        outcome=self.run_preflight(
            observed=replace(self.observed,buckets=(self.photo_bucket,)),
            custody=declared)
        self.assertEqual(outcome.credential_state,"CLAIMS_ONLY_UNVERIFIED")
        self.assertEqual(outcome.runtime_photo_upload,"DENY")
        with self.assertRaises(PhotoPreflightDenied):
            approve_live_setup(outcome)

    def test_wrong_region_and_inactive_project_denied(self):
        for fields in ({"region":"eu-west-1"},{"region":""},
                       {"project_status":"INACTIVE"},{"project_status":""}):
            with self.subTest(fields=fields),self.assertRaises(PhotoPreflightDenied):
                self.run_preflight(observed=replace(self.observed,**fields))

    def test_any_nonempty_storage_policy_requires_separate_review(self):
        for fields in ({"object_policy_count":1},{"bucket_policy_count":1},
                       {"object_policy_count":-1},{"object_policy_count":True},
                       {"bucket_policy_count":"0"}):
            with self.subTest(fields=fields),self.assertRaises(PhotoPreflightDenied):
                self.run_preflight(observed=replace(self.observed,**fields))

    def test_storage_rls_must_be_enabled_on_both(self):
        for fields in ({"objects_rls":False},{"buckets_rls":False},
                       {"objects_rls":1},{"buckets_rls":None}):
            with self.subTest(fields=fields),self.assertRaises(PhotoPreflightDenied):
                self.run_preflight(observed=replace(self.observed,**fields))

    def test_public_bucket_denied(self):
        with self.assertRaises(PhotoPreflightDenied):
            self.run_preflight(observed=replace(self.observed,
                buckets=(replace(self.photo_bucket,public=True),)))

    def test_wrong_name_extra_bucket_and_wrong_type_denied(self):
        for buckets in (
            (replace(self.photo_bucket,name="public-photo"),),
            (self.photo_bucket,self.photo_bucket),
            (self.photo_bucket,"not-a-bucket"),
            [self.photo_bucket],
        ):
            with self.subTest(buckets=buckets),self.assertRaises(PhotoPreflightDenied):
                self.run_preflight(observed=replace(self.observed,buckets=buckets))

    def test_wrong_size_rejected_even_one_byte_difference(self):
        for number in (0,-1,LIMIT_BYTES-1,LIMIT_BYTES+1,True,None):
            with self.subTest(size=number),self.assertRaises(PhotoPreflightDenied):
                self.run_preflight(observed=replace(self.observed,
                  buckets=(replace(self.photo_bucket,file_size_limit=number),)))

    def test_wrong_mime_allowlist_rejected(self):
        for types in (("image/png",),("image/png","text/html"),
                      ("image/png","image/png"),None,["image/png","image/jpeg"],
                      ("image/png",["image/jpeg"])):
            with self.subTest(mime=types),self.assertRaises(PhotoPreflightDenied):
                self.run_preflight(observed=replace(self.observed,
                    buckets=(replace(self.photo_bucket,allowed_mime_types=types),)))

    def test_forged_bad_credential_checklist_does_not_greenlight(self):
        with self.assertRaises(PhotoPreflightDenied):
            self.run_preflight(custody=replace(self.custody,backend_only="yes"))
        with self.assertRaises(PhotoPreflightDenied):
            self.run_preflight(custody={"backend_only":True})
        self.assertEqual(
            self.run_preflight(custody=replace(self.custody,backend_only=True)).credential_state,
            "REVIEW_OPEN")

    def test_bad_untrusted_observation_does_not_create_a_bucket(self):
        with self.assertRaises(PhotoPreflightDenied):
            inspect_offline_private_photo_setup(
                observed={"region":"us-east-1"},custody=self.custody)
        with self.assertRaises(PhotoPreflightDenied):
            self.run_preflight(proposal="my proposed bucket")
        self.assertEqual(self.observed.buckets,())


if __name__=="__main__":
    unittest.main()
