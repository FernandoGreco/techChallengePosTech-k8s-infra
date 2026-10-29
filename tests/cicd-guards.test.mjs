import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizePlan } from '../scripts/terraform-plan-summary.mjs';
import { seal, unseal } from '../scripts/plan-artifact.mjs';
import { resolveRequest, checkRequest, checkEnvironment } from '../scripts/require-apply-approval.mjs';
import { deploymentTarget, targets } from '../scripts/deployment-target.mjs';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

test('reject deletions and both replacement orderings without emitting attributes', () => {
  for (const actions of [['delete'], ['delete', 'create'], ['create', 'delete']]) {
    const result = summarizePlan({ resource_changes: [{ change: { actions, after: { password: 'synthetic-secret' } } }] });
    assert.equal(result.destructive, true);
    assert.equal(result.blocked, true);
    assert.ok(!JSON.stringify(result).includes('synthetic-secret'));
  }
  assert.equal(summarizePlan({ resource_changes: [{ change: { actions: ['update'] } }] }).destructive, false);
  assert.throws(() => summarizePlan({ resource_changes: [{ change: { actions: ['future-action'] } }] }));
});
test('EC2 user-data updates are blocked in place without exposing their contents', () => {
  for (const name of ['control_plane', 'worker']) {
    for (const field of ['user_data', 'user_data_base64']) {
      const plan = { resource_changes: [{ type: 'aws_instance', mode: 'managed',
        address: `module.ec2.aws_instance.${name}`,
        change: { actions: ['update'], before: { [field]: 'synthetic-old-bootstrap-private' },
          after: { [field]: 'synthetic-new-bootstrap-private' } } }] };
      const result = summarizePlan(plan);
      assert.equal(result.update, 1);
      assert.equal(result.destructive, false);
      assert.equal(result.blocked, true);
      assert.equal(result.blocked_user_data_updates, 1);
      assert.deepEqual(result.resources[0].changed_fields, [field]);
      assert.ok(!JSON.stringify(result).includes('synthetic-old-bootstrap-private'));
      assert.ok(!JSON.stringify(result).includes('synthetic-new-bootstrap-private'));
    }
  }
});

test('unknown or removed EC2 user-data cannot bypass the update guard', () => {
  for (const field of ['user_data', 'user_data_base64']) {
    for (const change of [
      { before: { [field]: 'synthetic-bootstrap' }, after: { [field]: null } },
      { before: { [field]: null }, after: {}, after_unknown: { [field]: true } },
    ]) {
      const result = summarizePlan({ resource_changes: [{ type: 'aws_instance',
        change: { actions: ['update'], ...change } }] });
      assert.equal(result.blocked, true);
      assert.equal(result.blocked_user_data_updates, 1);
      assert.ok(result.resources[0].changed_fields.includes(field));
    }
  }
});

test('initial EC2 creation, no-op and tag-only updates remain allowed', () => {
  for (const change of [
    { actions: ['create'], before: null, after: { user_data: 'synthetic-bootstrap' } },
    { actions: ['no-op'], before: { user_data: 'same' }, after: { user_data: 'same' } },
    { actions: ['update'], before: { user_data: 'same', tags: { Role: 'old' } },
      after: { user_data: 'same', tags: { Role: 'new' } }, after_unknown: { public_ip: true } },
  ]) {
    const result = summarizePlan({ resource_changes: [{ type: 'aws_instance', change }] });
    assert.equal(result.blocked, false);
    assert.equal(result.blocked_user_data_updates, 0);
  }
});
test('node-disrupting EC2 updates are blocked for either Terraform environment', () => {
  for (const target of Object.values(targets)) {
    for (const key of ['ami', 'instance_type', 'subnet_id', 'availability_zone', 'key_name',
      'root_block_device', 'vpc_security_group_ids', 'source_dest_check']) {
      for (const change of [
        { before: { [key]: 'old-private' }, after: { [key]: 'new-private' } },
        { before: { [key]: 'old-private' }, after: {}, after_unknown: { [key]: true } },
        { before: { [key]: 'same' }, after: { [key]: 'same' }, after_unknown: { [key]: [{ nested: true }] } },
      ]) {
        const result = summarizePlan({ resource_changes: [{ type: 'aws_instance',
          address: 'module.ec2.aws_instance.worker', change: { actions: ['update'], ...change } }] });
        assert.equal(result.blocked, true, `${target.branch}:${key}`);
        assert.equal(result.blocked_instance_updates, 1);
        assert.ok(!JSON.stringify(result).includes('old-private'));
        assert.ok(!JSON.stringify(result).includes('new-private'));
      }
    }
  }
});

test('encrypted roots are allowed on creation but encryption changes on existing nodes are blocked', () => {
  for (const environment of ['homolog', 'production']) {
    for (const name of ['control_plane', 'worker']) {
      const attributes = encrypted => ({
        tags: { Environment: environment },
        root_block_device: [{ volume_size: 20, volume_type: 'gp3', encrypted }],
      });
      const resource = { type: 'aws_instance', mode: 'managed', address: `module.ec2.aws_instance.${name}` };
      const created = summarizePlan({ resource_changes: [{ ...resource,
        change: { actions: ['create'], before: null, after: attributes(true) } }] });
      assert.equal(created.create, 1);
      assert.equal(created.blocked, false);
      for (const beforeEncrypted of [false, true]) {
        const updated = summarizePlan({ resource_changes: [{ ...resource,
          change: { actions: ['update'], before: attributes(beforeEncrypted), after: attributes(!beforeEncrypted) } }] });
        assert.equal(updated.blocked, true);
        assert.equal(updated.blocked_instance_updates, 1);
        assert.deepEqual(updated.resources[0].changed_fields, ['root_block_device']);
      }
      const unchanged = summarizePlan({ resource_changes: [{ ...resource,
        change: { actions: ['no-op'], before: attributes(false), after: attributes(false) } }] });
      assert.equal(unchanged.blocked, false);
    }
  }
});

test('summary CLI exits nonzero for EC2 user-data updates and zero for tag-only updates', () => {
  for (const change of [
    { actions: ['update'], before: { user_data: 'synthetic-old-private' }, after: { user_data: 'synthetic-new-private' } },
    { actions: ['update'], before: { user_data: null }, after: {}, after_unknown: { user_data: true } },
  ]) {
    const result = spawnSync(process.execPath, ['scripts/terraform-plan-summary.mjs'], {
      encoding: 'utf8', input: JSON.stringify({ resource_changes: [{ type: 'aws_instance', change }] }),
    });
    assert.equal(result.status, 2);
    assert.equal(JSON.parse(result.stdout).blocked_user_data_updates, 1);
    assert.ok(!result.stdout.includes('synthetic-old-private'));
    assert.ok(!result.stdout.includes('synthetic-new-private'));
  }
  const safe = spawnSync(process.execPath, ['scripts/terraform-plan-summary.mjs'], {
    encoding: 'utf8', input: JSON.stringify({ resource_changes: [{ type: 'aws_instance',
      change: { actions: ['update'], before: { tags: { Name: 'old' } }, after: { tags: { Name: 'new' } } } }] }),
  });
  assert.equal(safe.status, 0);
  assert.equal(JSON.parse(safe.stdout).blocked, false);
});

test('artifact rejects tampering, wrong key, expired plan and wrong commit/run/account/region', () => {
  const key = 'synthetic-test-key-with-more-than-32-characters';
  const context = { commit: 'abc', run: '123', account: '000000000000', region: 'test-region',
    repository: 'test/repository', environment: 'homolog', bucket: 'test-bucket',
    stateKey: 'homolog/terraform.tfstate', attempt: '1' };
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
const requestBase = {
  GITHUB_REPOSITORY: 'felipevrds/techChallengePosTech-k8s-infra',
  GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_REF: 'refs/heads/homolog',
};

test('homolog push requests plan and approval; other repositories, refs and events fail closed', () => {
  const push = { ...requestBase, GITHUB_EVENT_NAME: 'push' };
  assert.deepEqual(resolveRequest(push), { plan: true, apply: true });
  assert.doesNotThrow(() => checkRequest(push));
  for (const override of [
    { GITHUB_REF: 'refs/heads/main' }, { GITHUB_REF: 'refs/heads/feature/test' },
    { GITHUB_REF: 'refs/tags/homolog' }, { PUSH_DELETED: 'true' },
    { GITHUB_REPOSITORY: 'FernandoGreco/techChallengePosTech-k8s-infra' },
    { GITHUB_REPOSITORY: '' }, { GITHUB_EVENT_NAME: 'pull_request' },
    { GITHUB_EVENT_NAME: 'workflow_run' }, { GITHUB_EVENT_NAME: 'repository_dispatch' },
  ]) assert.throws(() => resolveRequest({ ...push, ...override }));
});

test('manual validation and plan never request apply; manual apply still requires explicit confirmation', () => {
  for (const action of ['', 'validate']) {
    const env = { ...requestBase, REQUESTED_ACTION: action, APPLY_CONFIRMATION: 'APLICAR HOMOLOG' };
    assert.deepEqual(resolveRequest(env), { plan: false, apply: false });
    assert.throws(() => checkRequest(env));
  }
  const plan = { ...requestBase, REQUESTED_ACTION: 'plan', APPLY_CONFIRMATION: 'APLICAR HOMOLOG' };
  assert.deepEqual(resolveRequest(plan), { plan: true, apply: false });
  assert.throws(() => checkRequest(plan));
  const request = { ...requestBase, REQUESTED_ACTION: 'apply', APPLY_CONFIRMATION: 'APLICAR HOMOLOG' };
  assert.doesNotThrow(() => checkRequest(request));
  for (const override of [
    { GITHUB_REF: 'refs/heads/main' }, { APPLY_CONFIRMATION: '' },
    { APPLY_CONFIRMATION: 'aplicar homolog' }, { REQUESTED_ACTION: 'destroy' },
  ]) assert.throws(() => checkRequest({ ...request, ...override }));
  assert.deepEqual(resolveRequest({ ...plan, GITHUB_REF: 'refs/heads/main' }), { plan: true, apply: false });
  assert.throws(() => checkRequest({ ...plan, GITHUB_REF: 'refs/heads/main' }));
});

test('apply rejects missing reviewers, administrative bypass and any branch policy except homolog', () => {
  const environment = { can_admins_bypass: false, protection_rules: [{ type: 'required_reviewers', reviewers: [{}] }], deployment_branch_policy: { custom_branch_policies: true } };
  const policy = [{ name: 'homolog', type: 'branch' }];
  assert.doesNotThrow(() => checkEnvironment(environment, policy));
  assert.throws(() => checkEnvironment({ ...environment, protection_rules: [] }, policy));
  assert.throws(() => checkEnvironment({ ...environment, can_admins_bypass: true }, policy));
  assert.throws(() => checkEnvironment(environment, [{ name: '*', type: 'branch' }]));
  assert.throws(() => checkEnvironment({ ...environment, protection_rules: [{ type: 'required_reviewers', reviewers: [] }] }, policy));
  assert.throws(() => checkEnvironment(environment, [...policy, { name: 'main', type: 'branch' }]));
  assert.throws(() => checkEnvironment(environment, [{ name: 'homolog', type: 'tag' }]));
});

test('request CLI emits routing outputs without contacting AWS or the Environment API', () => {
  const dir = mkdtempSync(join(tmpdir(), 'tc3-request-'));
  const output = join(dir, 'outputs');
  try {
    for (const [event, action, confirmation, expected] of [
      ['push', '', '', 'plan=true\napply=true\n'],
      ['workflow_dispatch', 'validate', '', 'plan=false\napply=false\n'],
      ['workflow_dispatch', 'plan', '', 'plan=true\napply=false\n'],
      ['workflow_dispatch', 'apply', 'APLICAR HOMOLOG', 'plan=true\napply=true\n'],
    ]) {
      writeFileSync(output, '');
      const result = spawnSync(process.execPath, ['scripts/require-apply-approval.mjs', 'request'], {
        encoding: 'utf8', env: { ...process.env, ...requestBase, GITHUB_EVENT_NAME: event,
          REQUESTED_ACTION: action, APPLY_CONFIRMATION: confirmation, PUSH_DELETED: 'false',
          GITHUB_OUTPUT: output, GH_TOKEN: '', HTTPS_PROXY: 'http://127.0.0.1:1' },
      });
      assert.equal(result.status, 0, result.stderr);
      const text = readFileSync(output, 'utf8');
      assert.ok(text.startsWith(expected));
      if (expected.includes('plan=true')) {
        assert.ok(text.includes('environment=homolog\n'));
        assert.ok(text.includes('state_key=homolog/terraform.tfstate\n'));
      } else assert.equal(text, expected);
    }
    writeFileSync(output, '');
    const rejected = spawnSync(process.execPath, ['scripts/require-apply-approval.mjs', 'request'], {
      encoding: 'utf8', env: { ...process.env, ...requestBase, REQUESTED_ACTION: 'apply',
        APPLY_CONFIRMATION: '', GITHUB_OUTPUT: output, GH_TOKEN: '' },
    });
    assert.equal(rejected.status, 1);
    assert.equal(readFileSync(output, 'utf8'), '');
  } finally {
    if (existsSync(output)) unlinkSync(output);
    rmdirSync(dir);
  }
});
test('production push and manual apply require capacity review and target-specific confirmation', () => {
  const main = { ...requestBase, GITHUB_REF: 'refs/heads/main', PRODUCTION_CAPACITY_APPROVED: 'true' };
  assert.deepEqual(resolveRequest({ ...main, GITHUB_EVENT_NAME: 'push' }), { plan: true, apply: true });
  assert.deepEqual(resolveRequest({ ...main, REQUESTED_ACTION: 'plan' }), { plan: true, apply: false });
  assert.doesNotThrow(() => checkRequest({ ...main, REQUESTED_ACTION: 'apply', APPLY_CONFIRMATION: 'APLICAR PRODUCTION' }));
  for (const override of [{ PRODUCTION_CAPACITY_APPROVED: '' }, { PRODUCTION_CAPACITY_APPROVED: 'false' },
    { APPLY_CONFIRMATION: 'APLICAR HOMOLOG' }, { DEPLOY_ENVIRONMENT: 'homolog' }, { GITHUB_REF: 'refs/heads/production' }]) {
    assert.throws(() => checkRequest({ ...main, REQUESTED_ACTION: 'apply', APPLY_CONFIRMATION: 'APLICAR PRODUCTION', ...override }));
  }
  // A pure CI request remains available before enabling a second infrastructure.
  assert.deepEqual(resolveRequest({ ...main, PRODUCTION_CAPACITY_APPROVED: '', REQUESTED_ACTION: 'validate' }), { plan: false, apply: false });
});
test('only explicit production manual plan bypasses capacity approval and can never request apply', () => {
  for (const capacity of [undefined, '', 'false', 'true']) {
    const env = { ...requestBase, GITHUB_REF: 'refs/heads/main', REQUESTED_ACTION: 'plan' };
    if (capacity !== undefined) env.PRODUCTION_CAPACITY_APPROVED = capacity;
    assert.deepEqual(resolveRequest(env), { plan: true, apply: false });
    assert.throws(() => checkRequest(env));
    if (capacity !== 'true') {
      assert.throws(() => resolveRequest({ ...env, GITHUB_EVENT_NAME: 'push' }));
      assert.throws(() => resolveRequest({ ...env, REQUESTED_ACTION: 'apply', APPLY_CONFIRMATION: 'APLICAR PRODUCTION' }));
    }
    for (const override of [
      { GITHUB_EVENT_NAME: 'pull_request' }, { GITHUB_EVENT_NAME: 'workflow_run' },
      { GITHUB_REF: 'refs/heads/feature/test' }, { GITHUB_REF: 'refs/tags/main' },
      { GITHUB_REPOSITORY: 'other/repository' },
    ]) assert.throws(() => resolveRequest({ ...env, ...override }));
  }
});

test('repository adaptation is explicit and restricted to the known original repository', () => {
  const upstream = 'FernandoGreco/techChallengePosTech-k8s-infra';
  assert.throws(() => resolveRequest({ ...requestBase, GITHUB_REPOSITORY: upstream }));
  assert.deepEqual(resolveRequest({ ...requestBase, GITHUB_REPOSITORY: upstream, INFRA_DEPLOY_REPOSITORY: upstream }), { plan: false, apply: false });
  for (const name of ['other/repository', '*', '']) {
    assert.throws(() => resolveRequest({ ...requestBase, GITHUB_REPOSITORY: 'other/repository', INFRA_DEPLOY_REPOSITORY: name }));
  }
});
test('both Apply environments require reviewers, no admin bypass and the exact branch', () => {
  const environment = { can_admins_bypass: false, protection_rules: [{ type: 'required_reviewers', reviewers: [{}] }],
    deployment_branch_policy: { custom_branch_policies: true } };
  for (const branch of ['homolog', 'main']) {
    assert.doesNotThrow(() => checkEnvironment(environment, [{ name: branch, type: 'branch' }], branch));
    for (const policies of [[], [{ name: '*', type: 'branch' }], [{ name: branch, type: 'tag' }],
      [{ name: 'homolog', type: 'branch' }, { name: 'main', type: 'branch' }]]) {
      assert.throws(() => checkEnvironment(environment, policies, branch));
    }
    assert.throws(() => checkEnvironment({ ...environment, can_admins_bypass: true }, [{ name: branch, type: 'branch' }], branch));
    assert.throws(() => checkEnvironment({ ...environment, protection_rules: [] }, [{ name: branch, type: 'branch' }], branch));
  }
});
test('production routing CLI selects only the production state, directory and secret', () => {
  const dir = mkdtempSync(join(tmpdir(), 'tc3-production-routing-'));
  const output = join(dir, 'outputs');
  try {
    writeFileSync(output, '');
    const result = spawnSync(process.execPath, ['scripts/require-apply-approval.mjs', 'request'], {
      encoding: 'utf8', env: { ...process.env, ...requestBase, GITHUB_REF: 'refs/heads/main',
        GITHUB_EVENT_NAME: 'push', GITHUB_OUTPUT: output, PRODUCTION_CAPACITY_APPROVED: 'true',
        PUSH_DELETED: 'false', INFRA_DEPLOY_REPOSITORY: requestBase.GITHUB_REPOSITORY },
    });
    assert.equal(result.status, 0, result.stderr);
    const values = Object.fromEntries(readFileSync(output, 'utf8').trim().split('\n').map(x => x.split('=')));
    assert.deepEqual(values, { plan: 'true', apply: 'true', environment: 'production',
      directory: 'environments/production', apply_environment: 'production-apply',
      state_key: 'production/terraform.tfstate', tfvars_secret: 'TFVARS_PRODUCTION' });
  } finally { if (existsSync(output)) unlinkSync(output); rmdirSync(dir); }
});
test('Terraform targets have separate backend keys and environment tags; pipeline applies only a saved plan', () => {
  assert.notEqual(targets.homolog.stateKey, targets.production.stateKey);
  for (const [name, target] of Object.entries(targets)) {
    assert.equal(deploymentTarget({ GITHUB_REF: `refs/heads/${target.branch}` }).name, name);
    const versions = readFileSync(`${target.directory}/versions.tf`, 'utf8');
    assert.ok(versions.includes(`key          = "${target.stateKey}"`));
    assert.match(versions, /use_lockfile\s*=\s*true/);
    assert.ok(readFileSync(`${target.directory}/providers.tf`, 'utf8').includes(`Environment = "${name}"`));
    assert.ok(readFileSync(`${target.directory}/main.tf`, 'utf8').includes(`environment       = "${name}"`));
    assert.equal(readFileSync(`${target.directory}/.terraform.lock.hcl`, 'utf8'), readFileSync('environments/homolog/.terraform.lock.hcl', 'utf8'));
  }
  const workflow = readFileSync('.github/workflows/terraform-deploy.yml', 'utf8');
  assert.match(workflow, /branches: \[homolog, main\]/);
  assert.ok(workflow.includes("group: terraform-infra-${{ github.ref == 'refs/heads/main' && 'production' || 'homolog' }}"));
  assert.ok(workflow.includes('environment: ${{ needs.request.outputs.apply_environment }}'));
  assert.ok(workflow.includes('TFVARS_CONTENT: ${{ secrets[needs.request.outputs.tfvars_secret] }}'));
  assert.equal((workflow.match(/terraform plan /g) || []).length, 1);
  assert.equal((workflow.match(/terraform apply /g) || []).length, 1);
  assert.match(workflow, /terraform apply -input=false -lock-timeout=60s "\$RUNNER_TEMP\/reviewed.tfplan"/);
  assert.equal((workflow.match(/node .*terraform-plan-summary.mjs/g) || []).length, 2);
  assert.ok(!workflow.includes('terraform destroy'));
  assert.ok(!workflow.includes('kubectl apply'));
  assert.equal((workflow.match(/TF_WORKSPACE: default/g) || []).length, 2);
  const ci = readFileSync('.github/workflows/terraform-validate.yml', 'utf8');
  assert.ok(ci.includes('for target in homolog production; do'));
  assert.ok(ci.includes("branches: ['feature/**']"));
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
