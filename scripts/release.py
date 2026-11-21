#!/usr/bin/env python3
"""Build/export with Xcode, and package only a verified notarized app.

Uses Xcode's signed-in account. Never accepts passwords or API keys as arguments.
The App Store export is local; uploading and submitting are separate actions.
"""
import argparse
import datetime
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / '.build' / 'release'
ARCHIVE = BUILD / 'Glassist.xcarchive'


def run(*args, capture=False):
    return subprocess.run(args, cwd=ROOT, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)


def team_id(value):
    if value and re.fullmatch(r'[A-Z0-9]{10}', value):
        return value
    raise ValueError('Pass --team with the active paid team ID shown in Xcode. Do not use an expired Personal Team.')


def archive(team):
    if ARCHIVE.exists():
        raise ValueError(f'Archive already exists: {ARCHIVE}. Preserve or rename it before building a new archive.')
    BUILD.mkdir(parents=True, exist_ok=True)
    run('xcodebuild', '-project', 'Glassist.xcodeproj', '-scheme', 'Glassist',
        '-configuration', 'Release', '-destination', 'generic/platform=macOS',
        '-archivePath', str(ARCHIVE), '-derivedDataPath', str(BUILD / 'DerivedData'),
        '-allowProvisioningUpdates', f'DEVELOPMENT_TEAM={team}', 'archive')


def export(team, channel):
    if not ARCHIVE.exists():
        raise ValueError('Build an archive first.')
    options = BUILD / f'ExportOptions-{channel}.plist'
    options.write_bytes(plistlib.dumps({'method': channel, 'destination': 'export',
        'teamID': team, 'signingStyle': 'automatic', 'manageAppVersionAndBuildNumber': False,
        'uploadSymbols': True}))
    run('xcodebuild', '-exportArchive', '-archivePath', str(ARCHIVE),
        '-exportOptionsPlist', str(options), '-exportPath', str(BUILD / channel),
        '-allowProvisioningUpdates')


def verify(app, team, notarized):
    app = app.resolve()
    if not app.is_dir() or app.name != 'Glassist.app':
        raise ValueError('Expected an exported Glassist.app directory.')
    host_info = None
    for bundle, identifier in [(app, 'com.frankwang.Glassist'),
                              (app / 'Contents/PlugIns/GlassistWidgets.appex', 'com.frankwang.Glassist.Widgets')]:
        info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != identifier:
            raise ValueError(f'Unexpected bundle identifier: {bundle}')
        version = (info['CFBundleShortVersionString'], info['CFBundleVersion'])
        if host_info is None:
            host_info = info
        elif version != (host_info['CFBundleShortVersionString'], host_info['CFBundleVersion']):
            raise ValueError('Host and extension versions differ.')
        run('codesign', '--verify', '--strict', '--verbose=2', str(bundle))
        signature = run('codesign', '-d', '--verbose=4', str(bundle), capture=True).stderr
        if 'Authority=Developer ID Application:' not in signature or f'TeamIdentifier={team}\n' not in signature:
            raise ValueError(f'Not Developer ID signed by the expected team: {bundle}')
        if '(runtime)' not in signature or 'Timestamp=' not in signature:
            raise ValueError('Hardened runtime and secure signing timestamp are required.')
        raw = run('codesign', '-d', '--entitlements', ':-', str(bundle), capture=True).stdout
        entitlements = plistlib.loads(raw.encode())
        if entitlements.get('com.apple.security.get-task-allow'):
            raise ValueError('Development debugging entitlement found in release.')
        if not entitlements.get('com.apple.security.app-sandbox'):
            raise ValueError('App Sandbox entitlement missing.')
        group = f'{team}.com.frankwang.Glassist'
        if group not in entitlements.get('com.apple.security.application-groups', []):
            raise ValueError('Shared App Group does not match the release team.')
        if info.get('GlassistKeychainGroup') not in entitlements.get('keychain-access-groups', []):
            raise ValueError('Shared Keychain entitlement does not match bundle configuration.')
        profile = bundle / 'Contents/embedded.provisionprofile'
        if profile.exists():
            decoded = plistlib.loads(run('security', 'cms', '-D', '-i', str(profile), capture=True).stdout.encode())
            if decoded['ExpirationDate'] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
                raise ValueError('Embedded provisioning profile has expired.')
            if team not in decoded.get('TeamIdentifier', []):
                raise ValueError('Provisioning profile belongs to a different team.')
        if not (bundle / 'Contents/Resources/PrivacyInfo.xcprivacy').exists():
            raise ValueError('Privacy manifest missing.')
    if not host_info.get('CFBundleIconName'):
        raise ValueError('App icon missing from exported app.')
    if notarized:
        run('xcrun', 'stapler', 'validate', str(app))
        run('spctl', '--assess', '--type', 'execute', '--verbose=4', str(app))
    return host_info


def package(app, team):
    info = verify(app, team, notarized=True)
    destination = ROOT / 'dist'
    destination.mkdir(exist_ok=True)
    name = f"Glassist-{info['CFBundleShortVersionString']}-{info['CFBundleVersion']}-macOS-arm64.zip"
    output = destination / name
    if output.exists():
        raise ValueError(f'Release package already exists: {output}')
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app.resolve()), str(output))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {name}\n')
    output.with_suffix('.zip.json').write_text(json.dumps({
        'file': name, 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
        'sha256': digest, 'bytes': output.stat().st_size, 'team': team,
        'signature': 'Developer ID Application', 'notarization': 'stapled and Gatekeeper accepted',
        'architecture': 'arm64', 'minimum_macos': '14.0',
        'second_mac_installation_verified': False,
    }, indent=2) + '\n')
    print(f'Verified release package: {output}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['archive', 'export', 'verify', 'package'])
    parser.add_argument('--team', required=True)
    parser.add_argument('--channel', choices=['developer-id', 'app-store-connect'], default='developer-id')
    parser.add_argument('--app', type=Path, default=BUILD / 'developer-id' / 'Glassist.app')
    parser.add_argument('--require-notarization', action='store_true')
    args = parser.parse_args()
    team = team_id(args.team)
    if args.action == 'archive': archive(team)
    elif args.action == 'export': export(team, args.channel)
    elif args.action == 'verify': verify(args.app, team, args.require_notarization)
    else: package(args.app, team)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
