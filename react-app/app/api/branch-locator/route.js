// SPDX-FileCopyrightText: GoCortexIO
// SPDX-License-Identifier: AGPL-3.0-or-later

// Intentionally vulnerable: Server-Side Request Forgery (SSRF)
// Nearest branch/ATM locator - fetches partner network status server-side.
export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const target = searchParams.get('endpoint') || 'https://partner-branch-api.example.com/status';

  // Vulnerable: fully attacker-controlled URL, no allow-list or scheme/host validation
  const res = await fetch(target);
  const body = await res.text();
  return new Response(body, { status: res.status });
}
