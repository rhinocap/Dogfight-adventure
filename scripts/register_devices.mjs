// Registers iOS devices with App Store Connect via the API, so xcodebuild can
// include them in a development provisioning profile. Uses a local .p8 API key.
//
// Usage: node register_devices.mjs <keyId> "<name>:<udid>" ["<name>:<udid>" ...]
// Reads issuer from ~/.appstoreconnect/issuer.txt and key from
// ~/.appstoreconnect/private_keys/AuthKey_<keyId>.p8
import { readFileSync } from 'node:fs';
import { createSign, createPrivateKey, sign as edSign } from 'node:crypto';
import { homedir } from 'node:os';
import crypto from 'node:crypto';

const [keyId, ...pairs] = process.argv.slice(2);
if (!keyId || pairs.length === 0) { console.error('args: <keyId> name:udid ...'); process.exit(2); }

const home = homedir();
const issuer = readFileSync(`${home}/.appstoreconnect/issuer.txt`, 'utf8').trim();
const p8 = readFileSync(`${home}/.appstoreconnect/private_keys/AuthKey_${keyId}.p8`, 'utf8');
const key = createPrivateKey(p8);

const b64u = (buf) => Buffer.from(buf).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64u(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
const payload = b64u(JSON.stringify({ iss: issuer, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }));
const signingInput = `${header}.${payload}`;
const sig = crypto.sign('SHA256', Buffer.from(signingInput), { key, dsaEncoding: 'ieee-p1363' });
const jwt = `${signingInput}.${b64u(sig)}`;

async function register(name, udid) {
  const body = { data: { type: 'devices', attributes: { name, platform: 'IOS', udid } } };
  const res = await fetch('https://api.appstoreconnect.apple.com/v1/devices', {
    method: 'POST',
    headers: { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (res.status === 201) { console.log(`OK   ${name} (${udid}) registered`); return true; }
  // Already-registered devices come back as a 409 conflict — treat as success.
  if (text.includes('already exists') || text.includes('DEVICE_ALREADY_EXISTS') || res.status === 409) {
    console.log(`OK   ${name} (${udid}) already registered`); return true;
  }
  console.error(`FAIL ${name} (${udid}) -> HTTP ${res.status}: ${text.slice(0, 400)}`);
  return false;
}

let ok = true;
for (const p of pairs) {
  const idx = p.indexOf(':');
  const name = p.slice(0, idx), udid = p.slice(idx + 1);
  ok = (await register(name, udid)) && ok;
}
process.exit(ok ? 0 : 1);
