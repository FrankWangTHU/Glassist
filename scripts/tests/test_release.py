import importlib.util
import plistlib
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('glassist_release', Path(__file__).parents[1] / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class DistributionSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = (Path(self.temp.name) / 'Glassist.app').resolve()
        self.team = 'ABCDE12345'
        self.signing = 'Developer ID Application: Test Publisher'
        self.widget_team = self.team
        self.debuggable = False
        self.reject_notary = False
        for bundle, identifier in [(self.app, 'com.frankwang.Glassist'),
                                   (self.app / 'Contents/PlugIns/GlassistWidgets.appex', 'com.frankwang.Glassist.Widgets')]:
            (bundle / 'Contents/Resources').mkdir(parents=True)
            (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': identifier, 'CFBundleShortVersionString': '0.4.0',
                'CFBundleVersion': '7', 'CFBundleIconName': 'AppIcon',
                'GlassistKeychainGroup': f'{self.team}.com.frankwang.Glassist.shared'}))
            (bundle / 'Contents/Resources/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({}))

    def command(self, *args, **kwargs):
        if args[:2] == ('codesign', '-d') and '--verbose=4' in args:
            team = self.widget_team if str(args[-1]).endswith('.appex') else self.team
            return types.SimpleNamespace(stdout='', stderr=f'Authority={self.signing}\nTeamIdentifier={team}\nflags=0x10000(runtime)\nTimestamp=Nov 21, 2026\n')
        if args[:3] == ('codesign', '-d', '--entitlements'):
            data = {'com.apple.security.app-sandbox': True,
                    'com.apple.security.get-task-allow': self.debuggable,
                    'com.apple.security.application-groups': [f'{self.team}.com.frankwang.Glassist'],
                    'keychain-access-groups': [f'{self.team}.com.frankwang.Glassist.shared']}
            return types.SimpleNamespace(stdout=plistlib.dumps(data).decode(), stderr='')
        if args[:3] == ('xcrun', 'stapler', 'validate') and self.reject_notary:
            raise subprocess.CalledProcessError(65, args)
        return types.SimpleNamespace(stdout='', stderr='')

    def test_development_signed_app_is_not_a_public_release(self):
        self.signing = 'Apple Development: Test Publisher'
        with patch.object(release, 'run', side_effect=self.command), self.assertRaisesRegex(ValueError, 'Not Developer ID'):
            release.verify(self.app, self.team, True)

    def test_widget_must_share_host_team(self):
        self.widget_team = 'WRONG12345'
        with patch.object(release, 'run', side_effect=self.command), self.assertRaisesRegex(ValueError, 'Not Developer ID'):
            release.verify(self.app, self.team, True)

    def test_debugging_entitlement_is_rejected(self):
        self.debuggable = True
        with patch.object(release, 'run', side_effect=self.command), self.assertRaisesRegex(ValueError, 'debugging'):
            release.verify(self.app, self.team, True)

    def test_failed_notarization_prevents_packaging(self):
        self.reject_notary = True
        with patch.object(release, 'run', side_effect=self.command) as commands, self.assertRaises(subprocess.CalledProcessError):
            release.package(self.app, self.team)
        self.assertFalse(any(call.args[0] == 'ditto' for call in commands.call_args_list))

    def test_success_requires_stapled_ticket_and_gatekeeper(self):
        with patch.object(release, 'run', side_effect=self.command) as commands:
            result = release.verify(self.app, self.team, True)
        self.assertEqual(result['CFBundleVersion'], '7')
        calls = [call.args for call in commands.call_args_list]
        self.assertIn(('xcrun', 'stapler', 'validate', str(self.app)), calls)
        self.assertIn(('spctl', '--assess', '--type', 'execute', '--verbose=4', str(self.app)), calls)

    def test_mismatched_host_widget_version_is_rejected(self):
        path = self.app / 'Contents/PlugIns/GlassistWidgets.appex/Contents/Info.plist'
        info = plistlib.loads(path.read_bytes()); info['CFBundleVersion'] = '6'
        path.write_bytes(plistlib.dumps(info))
        with patch.object(release, 'run', side_effect=self.command), self.assertRaisesRegex(ValueError, 'versions differ'):
            release.verify(self.app, self.team, True)


if __name__ == '__main__':
    unittest.main()
