import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizePlan } from '../scripts/terraform-plan-summary.mjs';
import { seal, unseal } from '../scripts/plan-artifact.mjs';
import { checkRequest, checkEnvironment } from '../scripts/require-apply-approval.mjs';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, existsSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

test('reject deletions and both replacement orderings without emitting attributes', () => {
  for (const actions of [['delete'], ['delete', 'create'], ['create', 'delete']]) {
    const result = summarizePlan({ resource_changes: [{ change: { actions, after: { password: 'synthetic-secret' } } }] });
    assert.equal(result.destructive, true);
    assert.ok(!JSON.stringify(result).includes('synthetic-secret'));
  }
  assert.equal(summarizePlan({ resource_changes: [{ change: { actions: ['update'] } }] }).destructive, false);
  assert.throws(() => summarizePlan({ resource_changes: [{ change: { actions: ['future-action'] } }] }));
});
test('artifact rejects tampering, wrong key, expired plan and wrong commit/run/account/region', () => {
  const key = 'synthetic-test-key-with-more-than-32-characters';
  const context = { commit: 'abc', run: '123', account: '000000000000', region: 'test-region' };
  const bytes = Buffer.from('synthetic plan bytes');
  const encrypted = seal(bytes, key, context);
  assert.deepEqual(unseal(encrypted, key, context), bytes);
  assert.ok(!encrypted.includes(bytes));
  const tampered = Buffer.from(encrypted); tampered[tampered.length - 1] ^= 1;
  assert.throws(() => unseal(tampered, key, context));
  assert.throws(() => unseal(encrypted, 'wrong-key', context));
  for (const field of Object.keys(context)) assert.throws(() => unseal(encrypted, key, { ...context, [field]: 'other' }));
  assert.throws(() => unseal(encrypted, key, context, Date.now() + 5 * 60 * 60 * 1000));
});
test('apply rejects push, other branches, absent confirmation and unprotected Environment', () => {
  const request = { GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_REF: 'refs/heads/homolog', APPLY_CONFIRMATION: 'APLICAR HOMOLOG' };
  assert.doesNotThrow(() => checkRequest(request));
  for (const override of [{ GITHUB_EVENT_NAME: 'push' }, { GITHUB_REF: 'refs/heads/main' }, { APPLY_CONFIRMATION: '' }]) assert.throws(() => checkRequest({ ...request, ...override }));
  const environment = { can_admins_bypass: false, protection_rules: [{ type: 'required_reviewers', reviewers: [{}] }], deployment_branch_policy: { custom_branch_policies: true } };
  const policy = [{ name: 'homolog', type: 'branch' }];
  assert.doesNotThrow(() => checkEnvironment(environment, policy));
  assert.throws(() => checkEnvironment({ ...environment, protection_rules: [] }, policy));
  assert.throws(() => checkEnvironment({ ...environment, can_admins_bypass: true }, policy));
  assert.throws(() => checkEnvironment(environment, [{ name: '*', type: 'branch' }]));
});
test('legacy deploy refuses GitHub Actions before invoking AWS or Terraform', () => {
  const dir = mkdtempSync(join(tmpdir(), 'tc3-no-deploy-'));
  try {
    const marker = join(dir, 'unexpected-call');
    for (const command of ['aws', 'terraform']) writeFileSync(join(dir, command), `#!/bin/sh\necho called > '${marker.replaceAll('\\', '/')}'\nexit 88\n`, { mode: 0o755 });
    const bash = process.platform === 'win32' ? join(process.env.ProgramFiles, 'Git', 'bin', 'bash.exe') : '/bin/bash';
    const result = spawnSync(bash, ['--noprofile', '--norc', resolve('scripts/deploy.sh')], {
      encoding: 'utf8', env: { ...process.env, GITHUB_ACTIONS: 'true', PATH: dir + (process.platform === 'win32' ? ';' : ':') + process.env.PATH },
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /workflow/);
    const missingCredentials = spawnSync(bash, ['--noprofile', '--norc', resolve('scripts/check-aws-account.sh')], {
      encoding: 'utf8', env: { ...process.env, EXPECTED_AWS_ACCOUNT_ID: '000000000000', AWS_ACCESS_KEY_ID: '', AWS_SECRET_ACCESS_KEY: '', AWS_SESSION_TOKEN: '', PATH: dir + (process.platform === 'win32' ? ';' : ':') + process.env.PATH },
    });
    assert.equal(missingCredentials.status, 1);
    assert.match(missingCredentials.stderr, /all three temporary/);
    assert.equal(existsSync(marker), false);
  } finally {
    for (const name of ['aws', 'terraform', 'unexpected-call']) {
      const file = join(dir, name);
      if (existsSync(file)) unlinkSync(file);
    }
    rmdirSync(dir);
  }
});
