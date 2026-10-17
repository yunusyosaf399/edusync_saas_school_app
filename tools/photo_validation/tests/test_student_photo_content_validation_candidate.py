"""Quarantined Student portrait content gate: real PNG/JPEG decode tests."""
from __future__ import annotations
import hashlib
from io import BytesIO
import sys
from pathlib import Path
import unittest
from PIL import Image, PngImagePlugin
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from student_photo_content_validation_candidate import (
    LIMIT_BYTES, PhotoValidationDenied, validate_student_photo_content,
)


def make_image(fmt: str, *, metadata: bool = False) -> bytes:
    image = Image.new("RGB", (12, 8), (35, 60, 100))
    file = BytesIO()
    if fmt == "PNG":
        kw = {}
        if metadata:
            png_info = PngImagePlugin.PngInfo()
            png_info.add_text("Comment", "private parent data")
            kw["pnginfo"] = png_info
        image.save(file, format=fmt, **kw)
    else:
        image.save(file, format=fmt,
                   comment=b"private parent data" if metadata else b"")
    return file.getvalue()


class StudentPortraitContentValidatorTests(unittest.TestCase):
    def test_real_png_decoding_and_server_hash(self):
        result = validate_student_photo_content(make_image("PNG"), "image/png")
        self.assertEqual((result.pixel_width, result.pixel_height), (12, 8))
        self.assertEqual(result.byte_size, len(result.stored_bytes))
        self.assertEqual(result.sha256, hashlib.sha256(result.stored_bytes).digest())
        with Image.open(BytesIO(result.stored_bytes)) as image:
            image.load()
            self.assertEqual(image.format, "PNG")

    def test_real_jpeg_decoding_and_reencoding(self):
        result = validate_student_photo_content(make_image("JPEG"), "image/jpeg")
        self.assertEqual(result.byte_size, len(result.stored_bytes))
        self.assertEqual(result.sha256, hashlib.sha256(result.stored_bytes).digest())
        self.assertTrue(result.stored_bytes.endswith(b"\xff\xd9"))
        with Image.open(BytesIO(result.stored_bytes)) as image:
            image.load()
            self.assertEqual(image.format, "JPEG")

    def test_png_metadata_is_removed(self):
        raw = make_image("PNG", metadata=True)
        self.assertIn(b"private parent data", raw)
        result = validate_student_photo_content(raw, "image/png")
        self.assertNotIn(b"private parent data", result.stored_bytes)

    def test_reject_mismatch_pdf_fake_corrupt_truncated_and_appended_payloads(self):
        png = make_image("PNG")
        jpeg = make_image("JPEG")
        invalid = [
            (png, "image/jpeg"), (jpeg, "image/png"),
            (b"%PDF-1.4\n"+png, "image/png"),
            (b"\x89PNG\r\n\x1a\n"+b"N"*20+
             b"\x00\x00\x00\x00IEND\xaeB\x60\x82", "image/png"),
            (png[:-10], "image/png"),
            (jpeg[:len(jpeg)//2]+b"\xff\xd9", "image/jpeg"),
            (png+b"<script>abc</script>", "image/png"),
            (jpeg+b"<script>abc</script>", "image/jpeg"),
            (b"", "image/png"),
            (b"X"*(LIMIT_BYTES+1), "image/png"),
        ]
        for data, mime in invalid:
            with self.subTest(mime=mime, size=len(data)):
                with self.assertRaises(PhotoValidationDenied):
                    validate_student_photo_content(data, mime)

    def test_reject_bad_mime_purpose_and_non_byte_input(self):
        png = make_image("PNG")
        for data, mime, purpose in [
            (png, "image/gif", "STUDENT_PROFILE_PHOTO"),
            (png, "application/pdf", "STUDENT_PROFILE_PHOTO"),
            (png, "image/png", "BIRTH_CERTIFICATE"),
            (png, "image/png", "EMPLOYEE_PROFILE_PHOTO"),
            (bytearray(png), "image/png", "STUDENT_PROFILE_PHOTO"),
        ]:
            with self.subTest(mime=mime, purpose=purpose):
                with self.assertRaises(PhotoValidationDenied):
                    validate_student_photo_content(data, mime, purpose=purpose)

    def test_reject_corrupted_png_crc(self):
        png = bytearray(make_image("PNG"))
        png[45] ^= 1
        with self.assertRaises(PhotoValidationDenied):
            validate_student_photo_content(bytes(png), "image/png")

    def test_reject_multiframe_apng(self):
        a = Image.new("RGBA", (5, 5), "red")
        b = Image.new("RGBA", (5, 5), "blue")
        data = BytesIO()
        a.save(data, format="PNG", save_all=True, append_images=[b], duration=100)
        with self.assertRaises(PhotoValidationDenied):
            validate_student_photo_content(data.getvalue(), "image/png")

    def test_measured_hash_never_relies_on_client_claims(self):
        result = validate_student_photo_content(make_image("JPEG"), "image/jpeg")
        self.assertEqual(len(result.sha256), 32)
        self.assertNotEqual(result.sha256, hashlib.sha256(b"client says OK").digest())


    def test_jpeg_exif_orientation_and_private_text_removed(self):
        # EXIF orientation must be applied to pixels, never copied to storage.
        photo = Image.new("RGB", (13, 7), (200, 10, 50))
        exif = Image.Exif()
        exif[274] = 6  # 90-degree orientation in untrusted source metadata.
        exif[270] = "private parent data"
        source = BytesIO()
        photo.save(source, format="JPEG", exif=exif)
        raw = source.getvalue()
        self.assertIn(b"private parent data", raw)
        result = validate_student_photo_content(raw, "image/jpeg")
        self.assertEqual((result.pixel_width, result.pixel_height), (7, 13))
        self.assertNotIn(b"private parent data", result.stored_bytes)
        self.assertEqual(result.sha256, hashlib.sha256(result.stored_bytes).digest())
        with Image.open(BytesIO(result.stored_bytes)) as clean:
            clean.load()
            self.assertEqual(clean.size, (7, 13))
            self.assertIsNone(clean.getexif().get(274))
            self.assertIsNone(clean.getexif().get(270))

    def test_png_alpha_survives_metadata_free_sanitization(self):
        source = BytesIO()
        Image.new("RGBA", (10, 12), (10, 20, 30, 73)).save(
            source, format="PNG"
        )
        result = validate_student_photo_content(source.getvalue(), "image/png")
        self.assertEqual((result.pixel_width, result.pixel_height), (10, 12))
        with Image.open(BytesIO(result.stored_bytes)) as clean:
            clean.load()
            self.assertEqual(clean.mode, "RGBA")
            self.assertEqual(clean.getpixel((0, 0)), (10, 20, 30, 73))

    def test_small_compressed_png_over_provisional_pixel_limit_denied(self):
        # Small compressed upload bytes do not imply a safe decoded allocation.
        source = BytesIO()
        Image.new("RGB", (2001, 2000), (0, 0, 0)).save(
            source, format="PNG", optimize=True
        )
        raw = source.getvalue()
        self.assertLess(len(raw), LIMIT_BYTES)
        with self.assertRaisesRegex(PhotoValidationDenied, "PHOTO_PIXEL_RESOURCE_CEILING"):
            validate_student_photo_content(raw, "image/png")


if __name__ == "__main__":
    unittest.main()
