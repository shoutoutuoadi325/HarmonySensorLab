#!/usr/bin/env python3
"""Fail publication preflight until the app contains a real public HTTPS policy URL."""
import ipaddress
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'entry/src/main/ets/model/PrivacyPolicyLink.ets'


def validate_url(value: str) -> None:
    if not value:
        raise ValueError('PRIVACY_POLICY_URL is empty; obtain and verify the actual hosted policy before release.')
    if re.search(r"[\s\\<>\"']", value):
        raise ValueError('Privacy policy URL contains whitespace, escaping, or unsafe delimiters.')
    parts = urlsplit(value)
    host = parts.hostname or ''
    if parts.scheme != 'https' or not host or parts.username or parts.password or parts.port not in (None, 443):
        raise ValueError('Privacy policy URL must be a public HTTPS URL without credentials or a custom port.')
    if ':' in host or any(not re.fullmatch(r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?', label)
                          for label in host.split('.')):
        raise ValueError('Privacy policy URL must use a public DNS hostname.')
    lowered = host.lower()
    if '.' not in lowered or lowered in ('example.com', 'example.org', 'example.net') or any(
            lowered.endswith(suffix) for suffix in ('.localhost', '.local', '.test', '.invalid', '.example',
                                                    '.example.com', '.example.org', '.example.net')):
        raise ValueError('Privacy policy URL is local or a placeholder.')
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        raise ValueError('Privacy policy URL must use a public DNS hostname, not an IP address.')
    if lowered in ('github.com', 'github.io') or lowered.endswith(('.github.com', '.github.io')):
        raise ValueError('Huawei privacy FAQ excludes Github-hosted policies; use the verified eligible policy host.')


def main() -> int:
    try:
        source = SOURCE.read_text(encoding='utf-8')
        matches = re.findall(
            r"^export const PRIVACY_POLICY_URL: string = (['\"])([^\r\n]*?)\1;\s*$",
            source, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError('Expected exactly one literal PRIVACY_POLICY_URL configuration in the app source.')
        value = matches[0][1]
        validate_url(value)
        print(json.dumps({'passed': True, 'policyUrl': value,
                          'scope': 'Configuration only; hosted content and availability must also be verified.'},
                         ensure_ascii=False))
        return 0
    except (OSError, ValueError) as error:
        print(json.dumps({'passed': False, 'reason': str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
