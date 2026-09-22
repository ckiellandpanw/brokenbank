// SPDX-FileCopyrightText: GoCortexIO
// SPDX-License-Identifier: AGPL-3.0-or-later

// Intentionally vulnerable: Prototype Pollution (CWE-1321)
// Merges user-supplied terminal preference overrides into the defaults.
function deepMerge(target, source) {
  for (const key in source) {
    if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
      if (!target[key]) target[key] = {};
      // Vulnerable: no guard against __proto__/constructor/prototype keys, so a
      // crafted payload (e.g. {"__proto__":{"polluted":"yes"}}) walks the
      // prototype chain and pollutes Object.prototype for the whole process
      deepMerge(target[key], source[key]);
    } else {
      target[key] = source[key];
    }
  }
  return target;
}

const DEFAULT_PREFERENCES = {
  theme: 'green-on-black',
  soundEnabled: true,
  displayCurrency: 'AUD',
};

export async function POST(request) {
  const overrides = await request.json();
  const merged = deepMerge({ ...DEFAULT_PREFERENCES }, overrides);
  // Response.json/JSON.stringify only serialise own properties, so a polluted
  // Object.prototype key never appears on `merged` itself even when the
  // pollution succeeded. Reading it off a brand-new, empty object makes the
  // pollution directly observable in this same response (a real confirmation
  // oracle, not a claim that can't be checked over HTTP).
  const prototypePollutionProbe = ({}).bbchain06_polluted;
  return Response.json({ ...merged, _prototype_pollution_probe: prototypePollutionProbe });
}
