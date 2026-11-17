import datetime as dt
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('renewal', Path(__file__).parents[1] / 'renew-local-signing.py')
renewal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renewal)


class RenewalTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 11, 17, tzinfo=dt.timezone.utc)
        self.current = (self.now + dt.timedelta(days=1), ('same-team',))
        self.candidate = (self.now + dt.timedelta(days=7), ('same-team',))
        self.build = Mock()
        self.install = Mock()

    def run_renewal(self, current=None, candidate=None):
        candidate = candidate or self.candidate
        return renewal.renew(current or self.current, self.now, lambda: candidate,
                             self.build, self.install, lambda: candidate)

    def test_valid_install_does_not_build_or_replace(self):
        self.assertEqual(self.run_renewal(current=self.candidate)['status'], 'valid')
        self.build.assert_not_called()
        self.install.assert_not_called()

    def test_successful_build_with_reused_profile_does_not_replace(self):
        with self.assertRaisesRegex(ValueError, 'not extended'):
            self.run_renewal(candidate=self.current)
        self.build.assert_called_once()
        self.install.assert_not_called()

    def test_short_lived_replacement_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'not extended'):
            self.run_renewal(candidate=(self.now + dt.timedelta(hours=36), ('same-team',)))
        self.install.assert_not_called()

    def test_different_team_is_rejected_without_install(self):
        with self.assertRaisesRegex(ValueError, 'team changed'):
            self.run_renewal(candidate=(self.candidate[0], ('another-team',)))
        self.install.assert_not_called()

    def test_build_failure_preserves_current_app(self):
        self.build.side_effect = OSError('Build unavailable')
        with self.assertRaises(OSError):
            self.run_renewal()
        self.install.assert_not_called()

    def test_new_profiles_replace_and_report_verified_expiry(self):
        result = self.run_renewal()
        self.install.assert_called_once()
        self.assertEqual(result, {'status': 'renewed', 'expires_at': self.candidate[0].isoformat()})

    def test_expired_install_can_be_renewed(self):
        result = self.run_renewal(current=(self.now - dt.timedelta(days=1), ('same-team',)))
        self.assertEqual(result['status'], 'renewed')

    def test_post_install_mismatch_is_reported(self):
        with self.assertRaisesRegex(ValueError, 'did not match'):
            renewal.renew(self.current, self.now, lambda: self.candidate,
                          self.build, self.install, lambda: self.current)


if __name__ == '__main__':
    unittest.main()
