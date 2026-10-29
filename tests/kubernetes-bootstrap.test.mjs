import test from 'node:test';
import assert from 'node:assert/strict';
import { main, validateInventory, joinConfiguration, verifyMetricsTls } from '../scripts/bootstrap-production.mjs';

const account = '123456789012';
const ids = { controlPlane: 'i-00000000000000001', worker: 'i-00000000000000002' };
const instances = ['control-plane', 'worker'].map((role, index) => ({
  id: Object.values(ids)[index], state: 'running', publicIp: `203.0.113.${index + 1}`, privateIp: `10.0.0.${index + 1}`,
  tags: [{ Key: 'Environment', Value: 'production' }, { Key: 'Role', Value: role }],
}));

test('bootstrap binds both roles to the expected account and production instance IDs', () => {
  assert.deepEqual(validateInventory(instances, account, account, ids).map(x => x.role), ['control-plane', 'worker']);
  assert.throws(() => validateInventory(instances, account, '000000000000', ids));
  assert.throws(() => validateInventory(instances, account, account, { ...ids, worker: ids.controlPlane }));
  for (const change of [
    { state: 'stopped' }, { tags: [{ Key: 'Environment', Value: 'homolog' }, { Key: 'Role', Value: 'worker' }] },
    { publicIp: 'not-an-ip' }, { privateIp: 'not-an-ip' }, { id: 'i-99999999999999999' },
  ]) assert.throws(() => validateInventory([instances[0], { ...instances[1], ...change }], account, account, ids));
});

test('join configuration pins the CA and never enables unsafe discovery', () => {
  const fixture = 'abcdef.0123456789abcdef';
  const config = JSON.parse(joinConfiguration(fixture, '10.0.0.1', 'a'.repeat(64), 'worker-test'));
  assert.equal(config.discovery.bootstrapToken.token, fixture);
  assert.deepEqual(config.discovery.bootstrapToken.caCertHashes, ['sha256:' + 'a'.repeat(64)]);
  assert.equal(config.discovery.bootstrapToken.apiServerEndpoint, '10.0.0.1:6443');
  assert.equal(config.discovery.bootstrapToken.unsafeSkipCAVerification, undefined);
  for (const args of [[fixture + '\n', '10.0.0.1', 'a'.repeat(64), 'worker-test'],
    [fixture, 'not-an-ip', 'a'.repeat(64), 'worker-test'], [fixture, '10.0.0.1', 'bad-hash', 'worker-test'],
    [fixture, '10.0.0.1', 'a'.repeat(64), 'worker;invalid']]) {
    assert.throws(() => joinConfiguration(...args), error => !error.message.includes(fixture));
  }
});

test('unconfirmed bootstrap and Terraform runners stop before any external command', async () => {
  await assert.rejects(main({}), /CONFIRM_BOOTSTRAP_PRODUCTION_REQUIRED/);
  await assert.rejects(main({ GITHUB_ACTIONS: 'true', CONFIRM_BOOTSTRAP_PRODUCTION: 'sim' }), /POST_APPLY/);
});

test('TLS checks accept omitted false API fields but reject either bypass or missing CA', () => {
  const args = ['--kubelet-certificate-authority=/ca.crt', '--tls-cert-file=/tls.crt', '--tls-private-key-file=/tls.key'];
  const deployment = values => ({ spec: { template: { spec: { containers: [{ args: values }] } } } });
  verifyMetricsTls({ spec: { caBundle: 'public-test-ca' } }, deployment(args));
  verifyMetricsTls({ spec: { caBundle: 'public-test-ca', insecureSkipTLSVerify: false } }, deployment(args));
  assert.throws(() => verifyMetricsTls({ spec: { caBundle: 'public-test-ca', insecureSkipTLSVerify: true } }, deployment(args)));
  assert.throws(() => verifyMetricsTls({ spec: {} }, deployment(args)));
  assert.throws(() => verifyMetricsTls({ spec: { caBundle: 'public-test-ca' } }, deployment([...args, '--kubelet-insecure-tls'])));
  assert.throws(() => verifyMetricsTls({ spec: { caBundle: 'public-test-ca' } }, deployment(args.slice(1))));
});
