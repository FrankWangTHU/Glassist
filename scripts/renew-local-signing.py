#!/usr/bin/env python3
"""Check Personal Team provisioning, and renew through the signed-in Xcode account.

No credentials are read or stored by this script. A successful Xcode build is not
enough: the earliest profile expiry must advance beyond the installed deadline and the
48-hour renewal window before replacement.
"""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

UTC = dt.timezone.utc
ROOT = Path(__file__).resolve().parents[1]
INSTALLED = Path('/Applications/Glassist.app')
BUILT = ROOT / '.build/signed-xcode/Build/Products/Release/Glassist.app'
THRESHOLD = dt.timedelta(hours=48)


def provisioning(bundle):
    records = []
    for relative, identifier in [
        ('Contents', 'com.frankwang.Glassist'),
        ('Contents/PlugIns/GlassistWidgets.appex/Contents', 'com.frankwang.Glassist.Widgets'),
    ]:
        contents = bundle / relative
        with (contents / 'Info.plist').open('rb') as stream:
            if plistlib.load(stream).get('CFBundleIdentifier') != identifier:
                raise ValueError('Unexpected application identity; no changes made.')
        raw = subprocess.check_output(
            ['/usr/bin/security', 'cms', '-D', '-i', str(contents / 'embedded.provisionprofile')],
            stderr=subprocess.DEVNULL, timeout=20)
        profile = plistlib.loads(raw)
        expiry = profile['ExpirationDate'].replace(tzinfo=UTC)
        team = tuple(profile['TeamIdentifier'])
        if not team:
            raise ValueError('Missing signing team; no changes made.')
        records.append((expiry, team))
    if records[0][1] != records[1][1]:
        raise ValueError('The app and widget signing teams differ; no changes made.')
    return min(value[0] for value in records), records[0][1]


def renew(current, now, read_built, build, install, read_installed):
    deadline, team = current
    if deadline - now > THRESHOLD:
        return {'status': 'valid', 'expires_at': deadline.isoformat()}
    build()
    candidate_deadline, candidate_team = read_built()
    if candidate_team != team:
        raise ValueError('Signing team changed. Keep the installed app and check Xcode.')
    if candidate_deadline <= max(deadline, now + THRESHOLD):
        raise ValueError('Xcode has not extended both provisioning profiles. The installed app was kept. Check the Xcode account, or retry later.')
    install()
    final_deadline, final_team = read_installed()
    if final_team != team or final_deadline < candidate_deadline:
        raise ValueError('Installed provisioning did not match the verified build. Check Xcode before retrying.')
    return {'status': 'renewed', 'expires_at': final_deadline.isoformat()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--renew', action='store_true', help='Attempt renewal only within 48 hours of expiry.')
    args = parser.parse_args()
    work = ROOT / '.build/renewal'
    work.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = (work / 'renewal.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print(json.dumps({'status': 'already_running'}))
        return 0
    try:
        now = dt.datetime.now(UTC)
        current = provisioning(INSTALLED)
        if not args.renew:
            result = {'status': 'needs_renewal' if current[0] - now <= THRESHOLD else 'valid',
                      'expires_at': current[0].isoformat()}
        else:
            def run_installer(build_only):
                log_path = work / ('build.log' if build_only else 'install.log')
                descriptor = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                with os.fdopen(descriptor, 'w') as log:
                    command = ['/bin/bash', str(ROOT / 'scripts/install-local.sh')]
                    if build_only:
                        command.append('--build-only')
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=1200)
            result = renew(current, now, lambda: provisioning(BUILT),
                           lambda: run_installer(True), lambda: run_installer(False),
                           lambda: provisioning(INSTALLED))
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException, subprocess.SubprocessError) as error:
        # Do not print build output, profile contents, account identities or credentials.
        message = str(error) if isinstance(error, ValueError) else 'Unable to verify or renew signing. Check Xcode sign-in, network and Keychain authorization; local logs are in .build/renewal.'
        print(json.dumps({'status': 'attention_required', 'message': message}))
        return 1
    finally:
        lock.close()


if __name__ == '__main__':
    sys.exit(main())
