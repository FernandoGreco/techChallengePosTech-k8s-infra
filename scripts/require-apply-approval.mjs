import { appendFileSync } from 'node:fs';
import { checkRepository, deploymentTarget } from './deployment-target.mjs';

export function resolveRequest(env) {
  checkRepository(env);
  const action = env.REQUESTED_ACTION || 'validate';
  if (env.GITHUB_EVENT_NAME === 'workflow_dispatch' && action === 'validate') {
    return { plan: false, apply: false };
  }
  const target = deploymentTarget(env);
  const planOnly = env.GITHUB_EVENT_NAME === 'workflow_dispatch' && action === 'plan';
  if (target.name === 'production' && !planOnly && env.PRODUCTION_CAPACITY_APPROVED !== 'true') {
    throw new Error('Production requires PRODUCTION_CAPACITY_APPROVED=true after capacity/cost review');
  }
  if (env.GITHUB_EVENT_NAME === 'push') {
    if (env.PUSH_DELETED === 'true') {
      throw new Error('Branch deletion cannot request approval');
    }
    return { plan: true, apply: true };
  }
  if (env.GITHUB_EVENT_NAME !== 'workflow_dispatch') {
    throw new Error('Unsupported workflow event');
  }
  if (!['validate', 'plan', 'apply'].includes(action)) throw new Error('Unsupported operation');
  if (action === 'apply' && env.APPLY_CONFIRMATION !== `APLICAR ${target.name.toUpperCase()}`) {
    throw new Error('Manual apply requires the target-specific confirmation');
  }
  return { plan: action !== 'validate', apply: action === 'apply' };
}
export function checkRequest(env) {
  if (!resolveRequest(env).apply) throw new Error('This request cannot apply a plan');
}
export function checkEnvironment(environment, policies, branch = 'homolog') {
  if (!environment.protection_rules?.some(rule => rule.type === 'required_reviewers' && rule.reviewers?.length > 0)) throw new Error('Required reviewers missing');
  if (environment.can_admins_bypass !== false) throw new Error('Disable administrator bypass');
  if (!['homolog', 'main'].includes(branch) || !environment.deployment_branch_policy?.custom_branch_policies || policies.length !== 1 || policies[0].name !== branch || policies[0].type !== 'branch') {
    throw new Error('Apply environment must allow only the target branch');
  }
}
if (process.argv[1]?.endsWith('require-apply-approval.mjs')) {
  try {
    if (process.argv[2] === 'request') {
      const request = resolveRequest(process.env);
      if (!process.env.GITHUB_OUTPUT) throw new Error('Job output file missing');
      appendFileSync(process.env.GITHUB_OUTPUT, `plan=${request.plan}\napply=${request.apply}\n`);
      if (request.plan) {
        const target = deploymentTarget(process.env);
        appendFileSync(process.env.GITHUB_OUTPUT, `environment=${target.name}\ndirectory=${target.directory}\napply_environment=${target.applyEnvironment}\nstate_key=${target.stateKey}\ntfvars_secret=${target.tfvarsSecret}\n`);
      }
      console.log(request.apply ? 'Plan and protected Environment approval requested.' : 'Validation or plan only; apply is disabled.');
    } else {
      checkRequest(process.env);
      const target = deploymentTarget(process.env);
      const base = `https://api.github.com/repos/${process.env.GITHUB_REPOSITORY}/environments/${target.applyEnvironment}`;
      const headers = { Authorization: `Bearer ${process.env.GH_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
      const get = async suffix => {
        const response = await fetch(base + suffix, { headers, signal: AbortSignal.timeout(10000) });
        if (!response.ok) throw new Error('Cannot verify Environment protections');
        return response.json();
      };
      const environment = await get('');
      const policy = await get('/deployment-branch-policies');
      checkEnvironment(environment, policy.branch_policies ?? [], target.branch);
      console.log('Authorized request and target Environment protections verified.');
    }
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
