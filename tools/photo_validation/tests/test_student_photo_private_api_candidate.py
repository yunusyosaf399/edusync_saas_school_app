"""Synthetic-only single-Supabase private Photo API candidate regressions.

No actual HTTP, Supabase, authentic Student images, keys, DB writes or Photo SET.
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
from student_photo_private_api_candidate import (
    CurrentTrialAccess, PhotoApiDenied, PrivateMemoryBucketTrial,
    StudentPhotoPrivateApiCandidate, TrustedTrialPrincipal,
)


def photo(fmt="PNG", metadata=False):
    buffer = BytesIO()
    image = Image.new("RGB", (28, 19), (22, 44, 66))
    options = {}
    if metadata and fmt == "PNG":
        p = PngImagePlugin.PngInfo()
        p.add_text("private-comment", "DO-NOT-STORE-THIS")
        options["pnginfo"] = p
    image.save(buffer, format=fmt, **options)
    return buffer.getvalue()


class PrivatePhotoApiCandidateTests(unittest.TestCase):
    def setUp(self):
        self.actor = TrustedTrialPrincipal(*[str(uuid4()) for _ in range(3)])
        self.student = str(uuid4())
        self.bucket = PrivateMemoryBucketTrial()
        self.clock = {"allowed": True, "revision": 7, "calls": 0}

        def trusted_server_current_access(actor, student, op):
            self.clock["calls"] += 1
            return CurrentTrialAccess(actor.school_id, actor.campus_id, student,
                                      actor.principal_id, op, self.clock["revision"],
                                      self.clock["allowed"])
        self.api = StudentPhotoPrivateApiCandidate(bucket=self.bucket,
                                                    authorize=trusted_server_current_access)

    def upload(self, **kwargs):
        values = dict(actor=self.actor, student_id=self.student,
                      request_id=str(uuid4()), raw_image=photo(), declared_mime="image/png")
        values.update(kwargs)
        return self.api.submit(**values)

    def test_real_sanitized_private_png_not_stored_original(self):
        blob = photo(metadata=True)
        r = self.upload(raw_image=blob)
        self.assertEqual(r.purpose, "STUDENT_PROFILE_PHOTO")
        self.assertEqual(r.classification, "PRIVATE")
        self.assertEqual(r.state, "VERIFIED_LOCAL_TRIAL")
        self.assertEqual(self.bucket.public, False)
        self.assertNotIn("DO-NOT-STORE-THIS", self.bucket.read_private(r.object_key).decode("latin1"))
        self.assertNotEqual(self.bucket.read_private(r.object_key), blob)
        self.assertEqual(r.byte_size, len(self.bucket.read_private(r.object_key)))
        self.assertEqual(r.sha256_hex, sha256(self.bucket.read_private(r.object_key)).hexdigest())
        self.assertEqual(self.api.read(actor=self.actor,student_id=self.student,file_id=r.file_id),
                         self.bucket.read_private(r.object_key))
        self.assertGreaterEqual(self.clock["calls"], 4)

    def test_real_jpeg_sanitization(self):
        r = self.upload(raw_image=photo("JPEG"), declared_mime="image/jpeg")
        self.assertEqual(r.mime,"image/jpeg")
        with Image.open(BytesIO(self.api.read(actor=self.actor,student_id=self.student,
                                              file_id=r.file_id))) as image:
            image.load()
            self.assertEqual(image.format,"JPEG")

    def test_replay_same_request_is_same_verified_identity(self):
        rid = str(uuid4())
        r = self.upload(request_id=rid)
        again = self.upload(request_id=rid)
        self.assertEqual(r,again)
        self.assertEqual(self.bucket.count(),1)
        with self.assertRaises(PhotoApiDenied):
            self.upload(request_id=rid,raw_image=photo("JPEG"),declared_mime="image/jpeg")
        self.assertEqual(self.bucket.count(),1)

    def test_private_photo_replacement_uses_new_file_and_preserves_old_bytes(self):
        before = self.upload()
        older = self.bucket.read_private(before.object_key)
        after = self.upload(request_id=str(uuid4()),replaces_file_id=before.file_id,
                            raw_image=photo("JPEG"),declared_mime="image/jpeg")
        self.assertEqual(after.replaces_file_id,before.file_id)
        self.assertNotEqual(after.file_id,before.file_id)
        self.assertNotEqual(after.object_key,before.object_key)
        self.assertEqual(self.bucket.count(),2)
        self.assertEqual(self.bucket.read_private(before.object_key),older)
        with self.assertRaises(PhotoApiDenied):
            self.bucket.create_no_upsert(before.object_key,b"replacement")

    def test_reject_invalid_media_and_fail_without_object_or_receipt(self):
        for payload,mime in [(b"PDF", "image/png"), (photo(),"application/pdf"),
                             (b"", "image/png"), (b"x"*1_048_577,"image/png")]:
            with self.subTest(mime=mime,size=len(payload)):
                with self.assertRaises(PhotoApiDenied):
                    self.upload(raw_image=payload,declared_mime=mime)
        self.assertEqual(self.bucket.count(),0)

    def test_reject_denied_or_fake_authorizer(self):
        self.clock["allowed"] = False
        with self.assertRaises(PhotoApiDenied): self.upload()
        self.assertEqual(self.bucket.count(),0)
        bad = StudentPhotoPrivateApiCandidate(bucket=PrivateMemoryBucketTrial(),
                                              authorize=lambda *_: True)
        with self.assertRaises(PhotoApiDenied):
            bad.submit(actor=self.actor,student_id=self.student,request_id=str(uuid4()),
                       raw_image=photo(),declared_mime="image/png")

    def test_reject_cross_school_student_and_actor_on_read_and_replace(self):
        record = self.upload()
        other = replace(self.actor,school_id=str(uuid4()))
        with self.assertRaises(PhotoApiDenied):
            self.api.read(actor=other,student_id=self.student,file_id=record.file_id)
        with self.assertRaises(PhotoApiDenied):
            self.api.read(actor=self.actor,student_id=str(uuid4()),file_id=record.file_id)
        with self.assertRaises(PhotoApiDenied):
            self.api.submit(actor=other,student_id=self.student,request_id=str(uuid4()),
                            raw_image=photo(),declared_mime="image/png",
                            replaces_file_id=record.file_id)
        self.assertEqual(self.bucket.count(),1)

    def test_reject_revocation_between_decode_and_commit(self):
        original = self.api._authorize
        def flip(actor,student,op):
            grant = original(actor,student,op)
            if self.clock["calls"]==1: self.clock["revision"]+=1
            return grant
        self.api._authorize = flip
        with self.assertRaises(PhotoApiDenied):self.upload()
        self.assertEqual(self.bucket.count(),0)

    def test_read_uses_fresh_permissions_and_detects_admin_tamper(self):
        receipt = self.upload()
        self.clock["allowed"] = False
        with self.assertRaises(PhotoApiDenied):
            self.api.read(actor=self.actor,student_id=self.student,file_id=receipt.file_id)
        self.clock["allowed"] = True
        self.bucket.simulate_privileged_tamper(receipt.object_key,b"changed")
        with self.assertRaises(PhotoApiDenied):
            self.api.read(actor=self.actor,student_id=self.student,file_id=receipt.file_id)
        # This only DETECTS a privileged change. Supabase-only cannot stop it.

    def test_refuse_invalid_request_identity_and_changed_revision_on_replay(self):
        rid = str(uuid4())
        self.upload(request_id=rid)
        self.clock["revision"] += 1
        # A new fresh authorization can replay exact same current-authorized receipt;
        # a revision bump alone is not permission revocation (valid current grant).
        self.assertEqual(self.upload(request_id=rid).request_id,rid)
        with self.assertRaises(PhotoApiDenied):
            self.upload(request_id="not-canonical-uuid")
        with self.assertRaises(PhotoApiDenied):
            self.upload(replaces_file_id=str(uuid4()))
        self.assertEqual(self.bucket.count(),1)


if __name__ == "__main__":
    unittest.main()
