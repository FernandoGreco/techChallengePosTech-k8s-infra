import { randomBytes, scryptSync, createCipheriv, createDecipheriv, createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const magic = Buffer.from('TC3PLAN1');
export function seal(plan, passphrase, context) {
  if (!passphrase || passphrase.length < 32) throw new Error('Encryption key must have at least 32 characters');
  const salt = randomBytes(16), iv = randomBytes(12);
  const key = scryptSync(passphrase, salt, 32);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  cipher.setAAD(magic);
  const payload = Buffer.from(JSON.stringify({ ...context, created: Date.now(), sha256: createHash('sha256').update(plan).digest('hex'), plan: plan.toString('base64') }));
  const encrypted = Buffer.concat([cipher.update(payload), cipher.final()]);
  return Buffer.concat([magic, salt, iv, cipher.getAuthTag(), encrypted]);
}
export function unseal(encrypted, passphrase, expected, now = Date.now()) {
  if (encrypted.length < 53 || !encrypted.subarray(0, 8).equals(magic)) throw new Error('Invalid artifact');
  const decipher = createDecipheriv('aes-256-gcm', scryptSync(passphrase, encrypted.subarray(8, 24), 32), encrypted.subarray(24, 36));
  decipher.setAAD(magic);
  decipher.setAuthTag(encrypted.subarray(36, 52));
  const payload = JSON.parse(Buffer.concat([decipher.update(encrypted.subarray(52)), decipher.final()]).toString());
  for (const key of ['commit', 'run', 'account', 'region']) {
    if (!expected[key] || payload[key] !== expected[key]) throw new Error('Artifact context mismatch');
  }
  if (!Number.isFinite(payload.created) || now < payload.created || now - payload.created > 4 * 60 * 60 * 1000) throw new Error('Plan expired; generate a new plan');
  const plan = Buffer.from(payload.plan, 'base64');
  if (createHash('sha256').update(plan).digest('hex') !== payload.sha256) throw new Error('Plan digest mismatch');
  return plan;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [mode, input, output] = process.argv.slice(2);
    const context = { commit: process.env.GITHUB_SHA, run: process.env.GITHUB_RUN_ID, account: process.env.EXPECTED_AWS_ACCOUNT_ID, region: process.env.AWS_REGION };
    if (Object.values(context).some(v => !v)) throw new Error('Missing context');
    const data = readFileSync(input);
    const result = mode === 'encrypt' ? seal(data, process.env.TF_PLAN_ENCRYPTION_KEY, context)
      : mode === 'decrypt' ? unseal(data, process.env.TF_PLAN_ENCRYPTION_KEY, context) : null;
    if (!result) throw new Error('Invalid mode');
    writeFileSync(output, result, { mode: 0o600 });
    console.log(mode === 'encrypt' ? 'Encrypted plan artifact prepared' : 'Plan integrity and context verified');
  } catch { console.error('Plan artifact verification failed; private details withheld'); process.exitCode = 1; }
}
