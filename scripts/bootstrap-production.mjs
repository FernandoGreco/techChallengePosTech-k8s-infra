import cp from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { isIP } from 'node:net';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const emit = value => console.log(JSON.stringify(value));
const quote = value => "'" + value.replaceAll("'", "'\"'\"'") + "'";

export function validateInventory(instances, expectedAccount, actualAccount, ids) {
  if (!/^\d{12}$/.test(expectedAccount) || actualAccount !== expectedAccount) throw Error('AWS_ACCOUNT_MISMATCH');
  if (instances.length !== 2 || ids.controlPlane === ids.worker) throw Error('EXPECTED_TWO_DISTINCT_PRODUCTION_INSTANCES');
  return ['control-plane', 'worker'].map(role => {
    const id = role === 'control-plane' ? ids.controlPlane : ids.worker;
    const node = instances.find(instance => instance.id === id);
    if (!node || node.state !== 'running' || !node.tags?.some(t => t.Key === 'Environment' && t.Value === 'production') ||
        !node.tags.some(t => t.Key === 'Role' && t.Value === role) || isIP(node.publicIp) !== 4 || isIP(node.privateIp) !== 4) {
      throw Error('PRODUCTION_INSTANCE_MAPPING_MISMATCH');
    }
    return { ...node, role };
  });
}

export function joinConfiguration(token, privateIp, caHash, nodeName) {
  if (!/^[a-z0-9]{6}\.[a-z0-9]{16}$/.test(token) || isIP(privateIp) !== 4 || !/^[a-f0-9]{64}$/.test(caHash) ||
      !/^[a-z0-9][a-z0-9-]*$/.test(nodeName)) throw Error('INVALID_JOIN_INPUT_WITHHELD');
  // The returned object is sent only on SSH stdin, never argv, disk or stdout.
  return JSON.stringify({ apiVersion: 'kubeadm.k8s.io/v1beta4', kind: 'JoinConfiguration',
    discovery: { bootstrapToken: { token, apiServerEndpoint: `${privateIp}:6443`, caCertHashes: [`sha256:${caHash}`] } },
    nodeRegistration: { name: nodeName, criSocket: 'unix:///var/run/containerd/containerd.sock' } });
}

export function verifyMetricsTls(apiService, deployment) {
  const skip = apiService.spec?.insecureSkipTLSVerify;
  const args = deployment.spec?.template?.spec?.containers?.[0]?.args ?? [];
  // The API omits false boolean fields from JSON; omission still means verify.
  if ((skip !== undefined && skip !== false) || !apiService.spec?.caBundle ||
      args.some(arg => arg.startsWith('--kubelet-insecure-tls')) ||
      !['--kubelet-certificate-authority=', '--tls-cert-file=', '--tls-private-key-file=']
        .every(prefix => args.some(arg => arg.startsWith(prefix) && arg.length > prefix.length))) {
    throw Error('METRICS_TLS_VERIFICATION_NOT_ENFORCED');
  }
}

function execute(file, args, { input = '', timeout = 30000, env = process.env } = {}) {
  return new Promise(resolve => {
    const child = cp.spawn(file, args, { env, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '', stderr = '', completed = false;
    const finish = status => { if (!completed) { completed = true; clearTimeout(timer); resolve({ status, stdout, stderr }); } };
    const timer = setTimeout(() => child.kill(), timeout);
    child.on('error', () => finish(255));
    child.on('close', code => finish(code ?? 255));
    child.stdout.on('data', chunk => { stdout += chunk; if (stdout.length > 4 * 1024 * 1024) child.kill(); });
    child.stderr.on('data', chunk => { stderr += chunk; if (stderr.length > 4 * 1024 * 1024) child.kill(); });
    child.stdin.on('error', () => {});
    child.stdin.end(input);
  });
}

export async function main(env = process.env) {
  if (env.GITHUB_ACTIONS === 'true') throw Error('USE_REVIEWED_POST_APPLY_ACCESS_NOT_THE_TERRAFORM_RUNNER');
  if (env.CONFIRM_BOOTSTRAP_PRODUCTION !== 'sim') throw Error('CONFIRM_BOOTSTRAP_PRODUCTION_REQUIRED');
  const ids = { controlPlane: env.CONTROL_PLANE_INSTANCE_ID, worker: env.WORKER_INSTANCE_ID };
  if (Object.values(ids).some(id => !/^i-[a-f0-9]{17}$/.test(id ?? ''))) throw Error('EXPLICIT_INSTANCE_IDS_REQUIRED');
  const region = env.AWS_REGION || 'us-east-1', profile = env.AWS_PROFILE || 'default';
  if (region !== 'us-east-1' || !/^[A-Za-z0-9_.-]+$/.test(profile)) throw Error('REGION_OR_PROFILE_INVALID');
  const expected = env.EXPECTED_AWS_ACCOUNT_ID;
  if (!/^\d{12}$/.test(expected ?? '')) throw Error('EXPECTED_AWS_ACCOUNT_ID_REQUIRED');
  const key = env.SSH_PRIVATE_KEY_PATH, known = env.SSH_KNOWN_HOSTS;
  if (![key, known].every(value => typeof value === 'string' && !/["\r\n]/.test(value))) throw Error('TRUSTED_SSH_PATHS_REQUIRED');
  fs.accessSync(key, fs.constants.R_OK);
  fs.accessSync(known, fs.constants.R_OK);
  const user = env.SSH_USER || 'ubuntu';
  if (!/^[a-z_][a-z0-9_-]*$/.test(user)) throw Error('SSH_USER_INVALID');
  const childEnv = { ...env, AWS_EC2_METADATA_DISABLED: 'true', AWS_MAX_ATTEMPTS: '1', AWS_PAGER: '' };
  for (const name of ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN']) delete childEnv[name];
  const aws = async args => {
    const result = await execute(env.AWS_CLI_EXECUTABLE || 'aws', [...args, '--profile', profile, '--region', region,
      '--output', 'json', '--no-cli-pager', '--cli-connect-timeout', '5', '--cli-read-timeout', '8'], { env: childEnv });
    if (result.status) throw Error('AWS_READ_PREFLIGHT_FAILED');
    return JSON.parse(result.stdout);
  };
  const identity = await aws(['sts', 'get-caller-identity']);
  if (identity.Account !== expected) throw Error('AWS_ACCOUNT_MISMATCH');
  const inventory = await aws(['ec2', 'describe-instances', '--instance-ids', ...Object.values(ids), '--query',
    'Reservations[].Instances[].{id:InstanceId,state:State.Name,publicIp:PublicIpAddress,privateIp:PrivateIpAddress,tags:Tags}']);
  const hosts = validateInventory(inventory, expected, identity.Account, ids);
  const ssh = env.SSH_EXECUTABLE || (process.platform === 'win32' ? path.join(env.ProgramFiles || 'C:/Program Files', 'Git/usr/bin/ssh.exe') : 'ssh');
  const remote = (role, command, options) => {
    const host = hosts.find(node => node.role === role);
    const alias = role === 'control-plane' ? env.SSH_CONTROL_PLANE_HOST_ALIAS : env.SSH_WORKER_HOST_ALIAS;
    if (alias && !/^[A-Za-z0-9._-]+$/.test(alias)) throw Error('INVALID_TRUSTED_HOST_ALIAS');
    return execute(ssh, ['-i', key, '-o', 'StrictHostKeyChecking=yes', '-o', 'UpdateHostKeys=no', '-o', 'BatchMode=yes',
      '-o', 'ConnectTimeout=5', '-o', 'ConnectionAttempts=1', '-o', `UserKnownHostsFile="${known.replaceAll('\\', '/')}"`,
      ...(alias ? ['-o', `HostKeyAlias=${alias}`] : []), `${user}@${host.publicIp}`, command], options);
  };
  const checked = (result, stage) => { if (result.status !== 0) throw Error(stage); return result.stdout; };
  const control = hosts[0], worker = hosts[1];
  for (const host of hosts) {
    const result = checked(await remote(host.role, 'set -e; cloud-init status; kubeadm version -o short; hostname -s; systemctl is-active containerd'), 'HOST_PREFLIGHT_FAILED');
    host.version = result.match(/v1\.\d+\.\d+/)?.[0];
    host.nodeName = result.split(/\r?\n/).find(line => /^ip-[0-9-]+$/.test(line));
    if (!host.nodeName || !host.version) throw Error('KUBEADM_VERSION_OR_NODE_NAME_MISSING');
  }
  if (control.version !== worker.version) throw Error('KUBEADM_VERSION_MISMATCH');
  checked(await remote('worker', `python3 -c 'import socket; s=socket.create_connection(("${control.privateIp}",6443),5); s.close()'`), 'WORKER_PRIVATE_API_UNREACHABLE');
  const nodes = JSON.parse(checked(await remote('control-plane', 'test "$(kubectl config current-context)" = kubernetes-admin@kubernetes && kubectl get nodes -o json'), 'CLUSTER_CONTEXT_FAILED'));
  if (nodes.items.some(node => !hosts.some(host => host.nodeName === node.metadata.name &&
      node.status.addresses.some(address => address.type === 'InternalIP' && address.address === host.privateIp)))) throw Error('UNEXPECTED_CLUSTER_NODE');
  let token;
  try {
    if (!nodes.items.some(node => node.metadata.name === worker.nodeName)) {
      checked(await remote('worker', 'test ! -f /etc/kubernetes/kubelet.conf'), 'WORKER_CONFIG_WITHOUT_REGISTERED_NODE');
      const result = checked(await remote('control-plane', 'sudo openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt -noout | openssl pkey -pubin -outform DER 2>/dev/null | openssl dgst -sha256 -r'), 'CA_HASH_FAILED');
      const caHash = result.trim().split(/\s+/)[0];
      token = checked(await remote('control-plane', 'sudo kubeadm token create --ttl 10m --description tc3-production-bootstrap'), 'SHORT_LIVED_TOKEN_FAILED').trim();
      const config = joinConfiguration(token, control.privateIp, caHash, worker.nodeName);
      checked(await remote('worker', 'sudo kubeadm join --config /dev/stdin', { input: config, timeout: 180000 }), 'JOIN_FAILED_NO_AUTOMATIC_RESET');
      emit({ workerJoin: 'completed', tokenExposed: false });
    } else emit({ workerJoin: 'already-registered' });
  } finally {
    if (token && /^[a-z0-9]{6}\.[a-z0-9]{16}$/.test(token)) {
      checked(await remote('control-plane', `sudo kubeadm token delete ${token.split('.')[0]}`), 'TEMPORARY_TOKEN_REVOCATION_FAILED');
      token = undefined;
    }
  }
  checked(await remote('control-plane', 'kubectl wait --for=condition=Ready nodes --all --timeout=180s', { timeout: 200000 }), 'NODES_NOT_READY');
  checked(await remote('control-plane', 'kubectl -n kube-system rollout status daemonset/calico-node --timeout=180s', { timeout: 200000 }), 'CALICO_NOT_READY');
  const helper = fs.readFileSync(path.join(root, 'scripts/kubelet-serving-tls.py'), 'utf8');
  for (const [role, action] of [['control-plane', 'configure-cluster'], ['control-plane', 'enable-node'], ['worker', 'enable-node']]) {
    checked(await remote(role, `sudo python3 - ${action}`, { input: helper }), 'SERVING_TLS_CONFIGURATION_FAILED');
  }
  const mapping = Object.fromEntries(hosts.map(host => [host.nodeName, host.privateIp]));
  checked(await remote('control-plane', 'sudo python3 - approve ' + quote(JSON.stringify(mapping)), { input: helper, timeout: 150000 }), 'SERVING_CSR_REVIEW_FAILED');
  for (const host of hosts) checked(await remote(host.role,
    `sudo openssl verify -CAfile /etc/kubernetes/pki/ca.crt -purpose sslserver -verify_ip ${host.privateIp} /var/lib/kubelet/pki/kubelet-server-current.pem`), 'KUBELET_CERTIFICATE_VERIFICATION_FAILED');
  const installer = fs.readFileSync(path.join(root, 'modules/ec2/user-data/install-metrics.sh'), 'utf8').replaceAll('\r\n', '\n');
  const runner = "import json,os,pathlib,subprocess,sys,tempfile; p=json.load(sys.stdin); os.umask(0o077)\nwith tempfile.TemporaryDirectory(prefix='tc3-metrics-',dir='/run') as d:\n h=pathlib.Path(d)/'helper.py'; b=pathlib.Path(d)/'install.sh'; h.write_text(p['helper']); b.write_text(p['installer']); e=dict(os.environ,DEPLOY_ENVIRONMENT='production',METRICS_TLS_MODE='secure',METRICS_TLS_HELPER=str(h)); sys.exit(subprocess.run(['bash',str(b)],env=e).returncode)\n";
  checked(await remote('control-plane', 'sudo python3 -c ' + quote(runner), { input: JSON.stringify({ helper, installer }), timeout: 340000 }), 'SECURE_METRICS_INSTALL_FAILED');
  const apiService = JSON.parse(checked(await remote('control-plane', 'kubectl get apiservice v1beta1.metrics.k8s.io -o json'), 'METRICS_APISERVICE_FAILED'));
  const metrics = JSON.parse(checked(await remote('control-plane', 'kubectl -n kube-system get deployment metrics-server -o json'), 'METRICS_DEPLOYMENT_FAILED'));
  verifyMetricsTls(apiService, metrics);
  const final = JSON.parse(checked(await remote('control-plane', 'kubectl get nodes -o json'), 'FINAL_NODE_QUERY_FAILED'));
  if (final.items.length !== 2 || final.items.some(node => !node.status.conditions.some(c => c.type === 'Ready' && c.status === 'True'))) throw Error('EXPECTED_TWO_READY_NODES');
  checked(await remote('control-plane', 'kubectl top nodes'), 'NODE_METRICS_UNAVAILABLE');
  emit({ result: 'PASS', environment: 'production', readyNodes: 2, secureMetrics: true, terraformExecuted: false, awsResourcesModified: false });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { emit({ result: 'STOP', stage: /^[A-Z0-9_]+$/.test(error.message) ? error.message : 'DETAILS_WITHHELD' }); process.exitCode = 1; });
}
