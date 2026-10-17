"""Quarantined, server-side Student portrait byte validator; not an upload API.

No entitlement, Student ownership, provenance, or DB mutations are performed.
Call only after the trusted upload service independently authenticates and
binds an upload intent to a specific Student/school, and only return the
validated bytes to that service. This module is a local acceptance candidate.
"""
from __future__ import annotations
from dataclasses import dataclass
import hashlib
from io import BytesIO
import warnings
from PIL import Image, ImageFile, ImageOps, UnidentifiedImageError

PURPOSE = "STUDENT_PROFILE_PHOTO"
LIMIT_BYTES = 1_048_576  # frozen S1 1..1,048,576 verified bytes
# Conservative provisional decoder resource ceiling; NOT a frozen product limit.
MAX_DECODED_PIXELS = 4_000_000
MIMES = {"image/png": "PNG", "image/jpeg": "JPEG"}
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
PNG_IEND = b"\x00\x00\x00\x00IEND\xaeB\x60\x82"


class PhotoValidationDenied(ValueError):
    """Fail-closed, non-sensitive rejection; never includes photo content."""


@dataclass(frozen=True, slots=True)
class ValidatedPortrait:
    # Persist these returned bytes, not the untrusted original blob.
    stored_bytes: bytes
    mime: str
    byte_size: int
    sha256: bytes
    pixel_width: int
    pixel_height: int


def validate_student_photo_content(
    raw: bytes, declared_mime: str, *, purpose: str = PURPOSE
) -> ValidatedPortrait:
    """Fully decode, sanitize and remeasure portrait bytes; no entitlement claim.

    Signature, stated MIME and actual decoder format must agree. Return the
    *sanitized* storage bytes and a server-measured SHA-256 of those bytes.
    Caller still needs current subscription, module, Student/school, ownership,
    trusted upload-intent/finalization and permission validation.
    """
    if purpose != PURPOSE or type(declared_mime) is not str or declared_mime not in MIMES:
        raise PhotoValidationDenied("PHOTO_PURPOSE_OR_MIME_DENIED")
    if type(raw) is not bytes or not (1 <= len(raw) <= LIMIT_BYTES):
        raise PhotoValidationDenied("PHOTO_SOURCE_SIZE_DENIED")
    kind = MIMES[declared_mime]
    if kind == "PNG":
        if not raw.startswith(PNG_MAGIC) or not raw.endswith(PNG_IEND):
            raise PhotoValidationDenied("PHOTO_PNG_SIGNATURE_OR_TRAILING_DATA")
    elif not (raw.startswith(b"\xff\xd8\xff") and raw.endswith(b"\xff\xd9")):
        raise PhotoValidationDenied("PHOTO_JPEG_SIGNATURE_OR_TRAILING_DATA")
    if ImageFile.LOAD_TRUNCATED_IMAGES:
        raise PhotoValidationDenied("PHOTO_DECODER_UNSAFE_CONFIGURATION")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(raw)) as first:
                if first.format != kind or getattr(first, "n_frames", 1) != 1:
                    raise PhotoValidationDenied("PHOTO_FORMAT_OR_FRAMES_DENIED")
                if first.width <= 0 or first.height <= 0:
                    raise PhotoValidationDenied("PHOTO_DIMENSIONS_DENIED")
                if first.width * first.height > MAX_DECODED_PIXELS:
                    raise PhotoValidationDenied("PHOTO_PIXEL_RESOURCE_CEILING")
                first.verify()
            # verify() does not guarantee full JPEG decoding; force load too.
            with Image.open(BytesIO(raw)) as image:
                if image.format != kind or getattr(image, "n_frames", 1) != 1:
                    raise PhotoValidationDenied("PHOTO_DECODER_TYPE_DENIED")
                image.load()
                cleaned = ImageOps.exif_transpose(image)
                # Reencoding strips EXIF/GPS, comments, text, profiles and
                # other metadata; never store the caller's original bytes.
                if kind == "JPEG":
                    cleaned = cleaned.convert("RGB")
                else:
                    alpha = "A" in cleaned.getbands() or "transparency" in cleaned.info
                    cleaned = cleaned.convert("RGBA" if alpha else "RGB")
                encoded = BytesIO()
                if kind == "JPEG":
                    cleaned.save(encoded, format="JPEG", quality=85, progressive=False)
                else:
                    cleaned.save(encoded, format="PNG", optimize=True)
                stored = encoded.getvalue()
    except PhotoValidationDenied:
        raise
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError, EOFError,
            Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise PhotoValidationDenied("PHOTO_DECODE_OR_VALIDATION_FAILED") from exc
    if not (1 <= len(stored) <= LIMIT_BYTES):
        raise PhotoValidationDenied("PHOTO_VERIFIED_SIZE_DENIED")
    if kind == "PNG":
        if not stored.startswith(PNG_MAGIC) or not stored.endswith(PNG_IEND):
            raise PhotoValidationDenied("PHOTO_SANITIZED_FORMAT_FAILED")
    elif not (stored.startswith(b"\xff\xd8\xff") and stored.endswith(b"\xff\xd9")):
        raise PhotoValidationDenied("PHOTO_SANITIZED_FORMAT_FAILED")
    return ValidatedPortrait(
        stored_bytes=stored, mime=declared_mime, byte_size=len(stored),
        sha256=hashlib.sha256(stored).digest(),
        pixel_width=cleaned.width, pixel_height=cleaned.height,
    )
