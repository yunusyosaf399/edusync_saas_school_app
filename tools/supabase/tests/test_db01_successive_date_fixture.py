"""Regression for UTC-hour-dependent successive Roll acceptance setup."""
import sys
import re
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from domain_db01_p1_successive_roll_ci import _successive_date_fixture, ROOT


class SuccessiveDateFixtureTests(unittest.TestCase):
    def test_original_utc_to_kiritimati_assumption_fails_before_10_utc(self):
        instant = datetime(2026, 10, 26, 3, 50, tzinfo=timezone.utc)
        self.assertEqual(instant.date(), instant.astimezone(ZoneInfo('Pacific/Kiritimati')).date())

    def test_new_school_dates_are_consecutive_at_every_utc_minute(self):
        west, east = ZoneInfo('Etc/GMT+10'), ZoneInfo('Pacific/Kiritimati')
        for year, month, day in [(2026, 10, 26), (2026, 12, 31), (2028, 2, 29)]:
            start = datetime(year, month, day, tzinfo=timezone.utc)
            for minute in range(24*60):
                instant = start + timedelta(minutes=minute)
                first = instant.astimezone(west).date()
                second = instant.astimezone(east).date()
                self.assertEqual(second, first+timedelta(days=1))
                self.assertLess(instant.date()-timedelta(days=2), first)

    def test_real_fixture_keeps_genuine_p0_and_approval_commands(self):
        source = (ROOT/'supabase/tests/domain/fixtures/db01_p1_review_two_backend_setup.sql').read_text()
        adjusted = _successive_date_fixture(source)
        self.assertIn("SET timezone='Etc/GMT+10'", adjusted)
        self.assertIsNone(re.search(r'CURRENT_DATE-1(?![0-9])', adjusted))
        self.assertEqual(len(re.findall(r'CURRENT_DATE-2(?![0-9])', adjusted)),
                         len(re.findall(r'CURRENT_DATE-1(?![0-9])', source)))
        self.assertIn('CURRENT_DATE-180', adjusted)
        self.assertIn('app.d1_place_student_enrollment(', adjusted)
        self.assertIn('app.d1_submit_student_roll_correction(', adjusted)
        self.assertNotIn('INSERT INTO app_private.roll_allocations', adjusted)
        self.assertNotIn('INSERT INTO app_private.enrollments', adjusted)

    def test_fixture_drift_fails_closed(self):
        for source in ('CURRENT_DATE-1', "SET timezone='UTC'", "SET timezone='UTC'; SET timezone='UTC'; CURRENT_DATE-1"):
            with self.assertRaisesRegex(RuntimeError, 'SUCCESSIVE_DATE_FIXTURE_DRIFT'):
                _successive_date_fixture(source)


if __name__ == '__main__':
    unittest.main()
