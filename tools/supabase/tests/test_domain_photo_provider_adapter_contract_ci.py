"""Security regression suite for the unactivated, synthetic-byte adapter contract.

No real photographs, cloud storage, Supabase changes, authentication token
verification or media decoding occur in these Python-only tests.
"""
from dataclasses import replace
from hashlib import sha256
from pathlib import Path
from uuid import uuid4
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from domain_photo_provider_adapter_contract_ci import (
    AckLost, Denied, LocalAdapterContractTrial, LocalPrivateByteProvider,
    TrustedTestContext, TRIAL_SECRET, MAX_BYTES,
    run_photo_provider_adapter_contract_trial,
)


class LocalPhotoProviderAdapterContractTests(unittest.TestCase):
    def setUp(self):
        self.clock=[1000]
        self.ctx=TrustedTestContext(*[str(uuid4()) for _ in range(4)])
        self.provider=LocalPrivateByteProvider()
        self.adapter=LocalAdapterContractTrial(
            provider=self.provider,school_id=self.ctx.school_id,
            now=lambda:self.clock[0],
            validator=lambda b:b.startswith(b"OPAQUE-TEST-"),
            server_key=TRIAL_SECRET)
        self.intent=self.adapter.allocate(self.ctx,ttl=60)
        self.payload=b"OPAQUE-TEST-ONLY-NOT-A-REAL-IMAGE"

    def test_disposable_runner(self):
        run_photo_provider_adapter_contract_trial()

    def test_allocates_immutable_private_logical_identity_not_file_row(self):
        i=self.intent
        self.assertEqual(i.purpose,"STUDENT_PROFILE_PHOTO")
        self.assertEqual(i.classification,"PRIVATE")
        self.assertEqual(i.location,"TRIAL_PRIVATE")
        self.assertIn(self.ctx.school_id,i.object_key)
        self.assertIn(i.file_id,i.object_key)
        self.assertNotIn("https://",i.object_key)
        self.assertEqual(self.adapter.evidence,{})
        self.assertEqual(self.provider.state(i.location,i.object_key),None)

    def test_lost_ack_put_is_exact_idempotent(self):
        with self.assertRaises(AckLost):
            self.adapter.put(self.ctx,self.intent,payload=self.payload,lose_ack=True)
        self.assertEqual(self.provider.state(
            self.intent.location,self.intent.object_key),"STAGED")
        self.assertTrue(self.adapter.put(
            self.ctx,self.intent,payload=self.payload))
        with self.assertRaises(Denied):
            self.adapter.put(self.ctx,self.intent,payload=self.payload+b"other")
        self.assertEqual(self.provider.read_back_for_validation(
            self.intent.location,self.intent.object_key),self.payload)

    def test_verified_read_back_and_permanent_trial_seal(self):
        digest=sha256(self.payload).hexdigest()
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        proof=self.adapter.inspect_trial(
            self.ctx,self.intent,expected_sha256=digest)
        self.assertEqual(proof.sha256_hex,digest)
        self.assertEqual(proof.byte_size,len(self.payload))
        self.assertTrue(self.adapter.verify_receipt(self.intent,proof))
        self.assertEqual(self.provider.state(
            self.intent.location,self.intent.object_key),"SEALED_TRIAL")
        self.assertEqual(self.adapter.inspect_trial(
            self.ctx,self.intent,expected_sha256=digest),proof)
        # Even exact re-PUT cannot mutate a sealed object.
        with self.assertRaises(Denied):
            self.adapter.put(self.ctx,self.intent,payload=self.payload)

    def test_head_etag_is_not_authoritative_provenance(self):
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        self.assertEqual(self.provider.head(
            self.intent.location,self.intent.object_key)["etag"],
                         "NOT_A_SHA256")
        with self.assertRaises(Denied):
            self.adapter.inspect_trial(
                self.ctx,self.intent,expected_sha256="0"*64)
        self.provider.tamper_bytes_for_test(
            self.intent.location,self.intent.object_key,b"TAMPER")
        with self.assertRaises(Denied):
            self.adapter.inspect_trial(
                self.ctx,self.intent,
                expected_sha256=sha256(self.payload).hexdigest())

    def test_server_validation_gate_required_and_no_available_transition(self):
        self.adapter.validator=lambda _:False
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        with self.assertRaises(Denied):
            self.adapter.inspect_trial(
                self.ctx,self.intent,
                expected_sha256=sha256(self.payload).hexdigest())
        self.assertEqual(self.adapter.evidence,{})
        self.assertEqual(self.provider.state(
            self.intent.location,self.intent.object_key),"STAGED")

    def test_forged_signed_evidence_is_rejected(self):
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        proof=self.adapter.inspect_trial(
            self.ctx,self.intent,
            expected_sha256=sha256(self.payload).hexdigest())
        for fake in (
            replace(proof,byte_size=proof.byte_size+1),
            replace(proof,sha256_hex="f"*64),
            replace(proof,receipt="0"*64),
            replace(proof,object_key="other-school/key"),
        ):
            with self.assertRaises(Denied):
                self.adapter.verify_receipt(self.intent,fake)

    def test_current_scope_checks_repeated_after_put(self):
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        digest=sha256(self.payload).hexdigest()
        for field in ("authenticated","permission","scope","current_primary",
                      "module_enabled","entitlement_fresh","purpose_enabled",
                      "file_upload"):
            with self.subTest(field=field):
                with self.assertRaises(Denied):
                    self.adapter.inspect_trial(
                        replace(self.ctx,**{field:False}),self.intent,
                        expected_sha256=digest)
        self.assertEqual(self.adapter.evidence,{})

    def test_different_actor_school_student_and_campus_denied(self):
        for field in ("school_id","student_id","campus_id","principal_id"):
            with self.subTest(field=field):
                other=replace(self.ctx,**{field:str(uuid4())})
                with self.assertRaises(Denied):
                    self.adapter.put(other,self.intent,payload=self.payload)

    def test_scope_and_expiry_checked_even_for_repeat_attempt(self):
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        self.clock[0]=self.intent.expiry
        with self.assertRaises(Denied):
            self.adapter.put(self.ctx,self.intent,payload=self.payload)
        with self.assertRaises(Denied):
            self.adapter.inspect_trial(
                self.ctx,self.intent,
                expected_sha256=sha256(self.payload).hexdigest())

    def test_inclusive_byte_limit_is_server_measured(self):
        self.assertTrue(self.adapter.put(
            self.ctx,self.intent,payload=b"A"*MAX_BYTES))
        for bad in (b"",b"B"*(MAX_BYTES+1)):
            with self.assertRaises(Denied):
                self.adapter.put(self.ctx,self.intent,payload=bad)
        self.assertEqual(len(self.provider.read_back_for_validation(
            self.intent.location,self.intent.object_key)),MAX_BYTES)

    def test_quarantine_preserves_evidence_and_alerts_without_delete(self):
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        proof=self.adapter.inspect_trial(
            self.ctx,self.intent,
            expected_sha256=sha256(self.payload).hexdigest())
        self.adapter.quarantine(self.intent,reason="CONTENT_MISMATCH")
        self.assertEqual(self.provider.state(
            self.intent.location,self.intent.object_key),"QUARANTINED")
        self.assertEqual(self.adapter.evidence[self.intent.intent_id],proof)
        with self.assertRaises(Denied):
            self.provider.read_back_for_validation(
                self.intent.location,self.intent.object_key)
        self.assertEqual(self.adapter.alerts,
                         [(self.intent.intent_id,"CONTENT_MISMATCH")])

    def test_retry_budget_and_alert_are_only_test_policy(self):
        self.assertEqual(self.adapter.bounded_reconcile(
            self.ctx,self.intent,attempt=1,max_attempts=2),"RETRY_LATER")
        self.assertEqual(self.adapter.bounded_reconcile(
            self.ctx,self.intent,attempt=2,max_attempts=2),"ALERT")
        self.assertEqual(self.adapter.alerts[-1],
                         (self.intent.intent_id,"RETRY_EXHAUSTED"))
        with self.assertRaises(Denied):
            self.adapter.bounded_reconcile(
                self.ctx,self.intent,attempt=11,max_attempts=11)
        with self.assertRaises(Denied):
            self.adapter.allocate(self.ctx,ttl=0)

    def test_stale_permission_reconciliation_is_non_destructive(self):
        self.adapter.put(self.ctx,self.intent,payload=self.payload)
        result=self.adapter.bounded_reconcile(
            replace(self.ctx,current_primary=False),
            self.intent,attempt=1,max_attempts=2)
        self.assertEqual(result,"QUARANTINED")
        self.assertEqual(self.provider.state(
            self.intent.location,self.intent.object_key),"QUARANTINED")
        self.assertEqual(self.adapter.alerts[-1],
                         (self.intent.intent_id,"AUTH_REVOKED"))


if __name__=="__main__":
    unittest.main()
