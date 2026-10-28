import { appendFileSync } from 'node:fs';

export function resolveRequest(env) {
  if (env.GITHUB_REPOSITORY !== 'felipevrds/techChallengePosTech-k8s-infra') {
    throw new Error('AWS operations are restricted to the infrastructure fork');
  }
  if (env.GITHUB_EVENT_NAME === 'push') {
    if (env.GITHUB_REF !== 'refs/heads/homolog' || env.PUSH_DELETED === 'true') {
      throw new Error('Only pushes to the existing homolog branch can request approval');
    }
    return { plan: true, apply: true };
  }
  if (env.GITHUB_EVENT_NAME !== 'workflow_dispatch') {
    throw new Error('Unsupported workflow event');
  }
  const action = env.REQUESTED_ACTION || 'validate';
  if (!['validate', 'plan', 'apply'].includes(action)) throw new Error('Unsupported operation');
  if (action !== 'validate' && env.GITHUB_REF !== 'refs/heads/homolog') {
    throw new Error('AWS operations are restricted to homolog');
  }
  if (action === 'apply' && env.APPLY_CONFIRMATION !== 'APLICAR HOMOLOG') {
    throw new Error('Manual apply requires APLICAR HOMOLOG');
  }
  return { plan: action !== 'validate', apply: action === 'apply' };
}
export function checkRequest(env) {
  if (!resolveRequest(env).apply) throw new Error('This request cannot apply a plan');
}
export function checkEnvironment(environment, policies) {
  if (!environment.protection_rules?.some(rule => rule.type === 'required_reviewers' && rule.reviewers?.length > 0)) throw new Error('Required reviewers missing');
  if (environment.can_admins_bypass !== false) throw new Error('Disable administrator bypass');
  if (!environment.deployment_branch_policy?.custom_branch_policies || policies.length !== 1 || policies[0].name !== 'homolog' || policies[0].type !== 'branch') {
    throw new Error('Apply environment must allow only homolog');
  }
}
if (process.argv[1]?.endsWith('require-apply-approval.mjs')) {
  try {
    if (process.argv[2] === 'request') {
      const request = resolveRequest(process.env);
      if (!process.env.GITHUB_OUTPUT) throw new Error('Job output file missing');
      appendFileSync(process.env.GITHUB_OUTPUT, `plan=${request.plan}\napply=${request.apply}\n`);
      console.log(request.apply ? 'Plan and protected Environment approval requested.' : 'Validation or plan only; apply is disabled.');
    } else {
      checkRequest(process.env);
      const base = `https://api.github.com/repos/${process.env.GITHUB_REPOSITORY}/environments/homolog-apply`;
      const headers = { Authorization: `Bearer ${process.env.GH_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
      const get = async suffix => {
        const response = await fetch(base + suffix, { headers, signal: AbortSignal.timeout(10000) });
        if (!response.ok) throw new Error('Cannot verify Environment protections');
        return response.json();
      };
      const environment = await get('');
      const policy = await get('/deployment-branch-policies');
      checkEnvironment(environment, policy.branch_policies ?? []);
      console.log('Authorized request and protected homolog-apply Environment verified.');
    }
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
