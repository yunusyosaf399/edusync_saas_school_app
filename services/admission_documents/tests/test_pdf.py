import hashlib
import subprocess
import unittest
from unittest.mock import patch

from services.admission_documents.service import Denied,MAX_BYTES,measure_certificate
from services.admission_documents.tests.pdf_fixtures import certificate_pdf


class PdfCertificateValidation(unittest.TestCase):
    def test_valid_pdf_preserves_original_bytes_and_hash(self):
        data=certificate_pdf()
        self.assertEqual(measure_certificate(data),('application/pdf',hashlib.sha256(data).digest()))
    def test_multiple_pages(self):
        self.assertEqual(measure_certificate(certificate_pdf(3))[0],'application/pdf')
    def test_invalid_pdf_structure(self):
        data=certificate_pdf()
        for invalid in (b'%PDF-1.7\nforged\n%%EOF',data[:100],b'junk'+data,data+b'executable payload'):
            with self.subTest(length=len(invalid)),self.assertRaises(Denied):measure_certificate(invalid)
    def test_encrypted_pdf(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(encrypted=True))
    def test_empty_password_encryption_still_denied(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(encrypted=True,password=''))
    def test_no_pages(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(0))
    def test_page_limit(self):
        self.assertEqual(measure_certificate(certificate_pdf(50))[0],'application/pdf')
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(51))
    def test_javascript(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(javascript=True))
    def test_embedded_file(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(attachment=True))
    def test_xfa(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(xfa=True))
    def test_decompression_limit(self):
        data=certificate_pdf(large_stream=True)
        self.assertLess(len(data),MAX_BYTES)
        with self.assertRaises(Denied):measure_certificate(data)
    def test_indirect_external_action(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(external_action=True))
    def test_external_stream(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(external_stream=True))
    def test_broken_page_content(self):
        with self.assertRaises(Denied):measure_certificate(certificate_pdf(broken_content=True))
    def test_same_inclusive_byte_limit(self):
        data=certificate_pdf();data+=b' '*(MAX_BYTES-len(data))
        self.assertEqual(measure_certificate(data)[0],'application/pdf')
        with self.assertRaises(Denied):measure_certificate(data+b' ')
    def test_parser_timeout_denies(self):
        with patch('services.admission_documents.service.subprocess.run',side_effect=subprocess.TimeoutExpired('pdf-validator',5)):
            with self.assertRaises(Denied):measure_certificate(certificate_pdf())
    def test_parser_crash_denies(self):
        with patch('services.admission_documents.service.subprocess.run',return_value=subprocess.CompletedProcess([], -9)):
            with self.assertRaises(Denied):measure_certificate(certificate_pdf())

if __name__=='__main__':unittest.main()
