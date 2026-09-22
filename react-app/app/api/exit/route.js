// SPDX-FileCopyrightText: GoCortexIO
// SPDX-License-Identifier: AGPL-3.0-or-later

// Intentionally vulnerable: Open Redirect
// Return-to-partner-portal deep link off the SpaceATM terminal.
export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const next = searchParams.get('next') || '/';

  // Vulnerable: no same-origin/allow-list validation on the redirect target
  return Response.redirect(next, 302);
}
