"""Synthetic Supabase private Storage REST wire-contract tests; no real network.

These tests ONLY plan requests and simulate responses with in-memory bytes.
No Supabase project, Storage bucket, API key, signed URL, JWT, upload or SQL.
"""
from dataclasses import replace
from hashlib import sha256
from io import BytesIO
from pathlib import Path
import sys
import unittest
from uuid import uuid4

from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from student_photo_content_validation_candidate import (
    validate_student_photo_content,
)
from student_photo_supabase_storage_adapter_candidate import (
    PrivateBucketProposal, PrivateObjectPlan, SupabaseCandidateDenied,
    SupabasePrivateStorageWireCandidate, PROPOSED_BUCKET, LIMIT_BYTES,
)


def sample_png(metadata: bool = False) -> bytes:
    f = BytesIO()
    im = Image.new("RGB", (12, 10), (48, 95, 162))
    props = {}
    if metadata:
        extra = PngImagePlugin.PngInfo()
        extra.add_text("student_private_note", "DO_NOT_STORE")
        props["pnginfo"] = extra
    im.save(f, format="PNG", **props)
    return f.getvalue()


class WireContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.adapter = SupabasePrivateStorageWireCandidate(PrivateBucketProposal())
        self.school = str(uuid4())
        self.file = str(uuid4())
        self.validated = validate_student_photo_content(sample_png(True), "image/png")

    def create(self):
        return self.adapter.plan_create(
            school_id=self.school, file_id=self.file, portrait=self.validated)

    def read(self):
        return self.adapter.plan_read_back(
            school_id=self.school, file_id=self.file,
            expected_sha256_hex=self.validated.sha256.hex(),
            expected_size=self.validated.byte_size)

    def test_private_bucket_manifest_is_review_only(self):
        b = self.adapter.proposal
        self.assertEqual(b.bucket_name, PROPOSED_BUCKET)
        self.assertIs(b.public, False)
        self.assertEqual(b.file_size_limit, 1_048_576)
        self.assertEqual(b.allowed_mime_types, ("image/jpeg", "image/png"))
        self.assertFalse(hasattr(self.adapter, "create_bucket"))

    def test_private_create_uses_real_supabase_rest_path_and_no_upsert(self):
        req = self.create()
        self.assertEqual(req.method, "POST")
        self.assertEqual(req.path,
            f"/storage/v1/object/{PROPOSED_BUCKET}/photo/{self.school}/{self.file}")
        self.assertEqual(dict(req.headers),
                         {"content-type": "image/png", "x-upsert": "false"})
        self.assertNotIn("apikey", dict(req.headers))
        self.assertNotIn("authorization", dict(req.headers))
        self.assertNotIn("http", req.path)
        self.assertEqual(req.body, self.validated.stored_bytes)
        self.assertNotIn("DO_NOT_STORE", req.body.decode("latin1"))
        self.assertNotEqual(req.body, sample_png(True))
        self.assertNotIn("body=b'", repr(req))
        self.assertEqual(req.expected_sha256_hex,sha256(req.body).hexdigest())

    def test_read_uses_private_authenticated_route_no_public_url(self):
        r = self.read()
        self.assertEqual(r.method,"GET")
        self.assertEqual(r.body,b"")
        self.assertEqual(r.headers,())
        self.assertEqual(
            r.path,
            f"/storage/v1/object/authenticated/{PROPOSED_BUCKET}/photo/{self.school}/{self.file}"
        )
        self.assertNotIn("/object/public/", r.path)
        self.assertEqual(r.expected_size, self.validated.byte_size)

    def test_ack_is_not_evidence_of_available_bytes(self):
        for status in (200,201):
            self.assertEqual(self.adapter.create_disposition(status), "ACKED_NOT_VERIFIED")
        for status in (0,202,204,400,401,403,404,409,412,429,500,503):
            self.assertEqual(self.adapter.create_disposition(status), "UNKNOWN_OR_REJECTED")
        with self.assertRaises(SupabaseCandidateDenied):
            self.adapter.create_disposition(True)

    def test_real_read_back_hash_and_actual_length(self):
        r=self.read()
        check=self.adapter.verify_private_read(
            r,status_code=200,body=self.validated.stored_bytes)
        self.assertEqual(check.sha256_hex,self.validated.sha256.hex())
        self.assertEqual(check.byte_size,self.validated.byte_size)
        self.assertFalse(hasattr(check, "state"))

    def test_wrong_status_or_bytes_are_not_verified(self):
        r=self.read()
        for status,body in ((201,self.validated.stored_bytes),
                            (404,self.validated.stored_bytes),
                            (200,b"bad"),
                            (200,self.validated.stored_bytes+b"x"),
                            (200,b"x"*self.validated.byte_size)):
            with self.subTest(status=status,size=len(body)):
                with self.assertRaises(SupabaseCandidateDenied):
                    self.adapter.verify_private_read(r,status_code=status,body=body)
        with self.assertRaises(SupabaseCandidateDenied):
            self.adapter.verify_private_read(r,status_code=200,body="not bytes")

    def test_reject_traversal_foreign_keys_and_noncanonical_ids(self):
        for bad in ("../../another-photo",str(uuid4()).upper(),"/photo/file",
                    "",self.school.replace("-",""),"not-a-uuid"):
            with self.subTest(bad=bad):
                with self.assertRaises(SupabaseCandidateDenied):
                    self.adapter.plan_read_back(
                        school_id=bad,file_id=self.file,
                        expected_sha256_hex=self.validated.sha256.hex(),
                        expected_size=self.validated.byte_size)
        with self.assertRaises(SupabaseCandidateDenied):
            self.adapter.plan_create(school_id=self.school,file_id="../x",
                                     portrait=self.validated)

    def test_reject_bucket_mutation_and_public_config(self):
        for kwargs in ({"public": True},{"bucket_name":"anything-else"},
                       {"file_size_limit":2_000_000},
                       {"allowed_mime_types":("image/png",)},
                       {"file_size_limit":True}):
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(SupabaseCandidateDenied):
                    PrivateBucketProposal(**kwargs)

    def test_cannot_supply_forged_or_inconsistent_sanitized_content(self):
        for bad in (replace(self.validated,sha256=b"\x00"*32),
                    replace(self.validated,byte_size=0),
                    replace(self.validated,mime="application/pdf"),
                    replace(self.validated,stored_bytes=b"not image"),
                    replace(self.validated,stored_bytes="not bytes"),
                    replace(self.validated,byte_size=True)):
            with self.assertRaises(SupabaseCandidateDenied):
                self.adapter.plan_create(school_id=self.school,file_id=self.file,
                                         portrait=bad)
        with self.assertRaises(SupabaseCandidateDenied):
            self.adapter.plan_create(school_id=self.school,file_id=self.file,
                                     portrait=sample_png())

    def test_reject_forged_read_expectation(self):
        for sha,size in ((self.validated.sha256.hex().upper(),self.validated.byte_size),
                         ("x"*64,self.validated.byte_size),
                         (self.validated.sha256.hex(),0),
                         (self.validated.sha256.hex(),True),
                         (self.validated.sha256.hex(),LIMIT_BYTES+1)):
            with self.subTest(size=size):
                with self.assertRaises(SupabaseCandidateDenied):
                    self.adapter.plan_read_back(
                        school_id=self.school,file_id=self.file,
                        expected_sha256_hex=sha, expected_size=size)

    def test_disallow_networking_delete_upsert_listing_and_any_untrusted_plan(self):
        for method in (self.adapter.send,self.adapter.delete,
                       self.adapter.upsert,self.adapter.list_objects):
            with self.assertRaises(SupabaseCandidateDenied):
                method()
        self.assertFalse(hasattr(self.adapter, "connect"))
        self.assertFalse(hasattr(self.adapter, "client"))
        self.assertFalse(hasattr(self.adapter, "sign_url"))
        with self.assertRaises(SupabaseCandidateDenied):
            PrivateObjectPlan("DELETE","/storage/v1/object/private",
                              tuple(),b"",self.validated.sha256.hex(),4)
        with self.assertRaises(SupabaseCandidateDenied):
            self.adapter.verify_private_read(self.create(),status_code=200,
                                             body=self.validated.stored_bytes)

    def test_distinct_file_keys_never_reuse_same_object_path(self):
        a=self.create()
        b=self.adapter.plan_create(school_id=self.school,
            file_id=str(uuid4()),portrait=self.validated)
        self.assertNotEqual(a.path,b.path)
        self.assertEqual(a.body,b.body)
        self.assertEqual(a.expected_sha256_hex,b.expected_sha256_hex)

    def test_actual_jpeg_sanitized_bytes_supported(self):
        src=BytesIO()
        Image.new("RGB",(13,14),(3,45,62)).save(src,format="JPEG")
        portrait=validate_student_photo_content(src.getvalue(),"image/jpeg")
        r=self.adapter.plan_create(school_id=self.school,file_id=self.file,
                                   portrait=portrait)
        self.assertEqual(dict(r.headers)["content-type"],"image/jpeg")
        self.assertEqual(r.expected_size,len(r.body))


if __name__ == "__main__":
    unittest.main()
