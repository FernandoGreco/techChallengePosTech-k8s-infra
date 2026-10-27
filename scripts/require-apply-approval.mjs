export function checkRequest(env) {
  if (env.GITHUB_EVENT_NAME !== 'workflow_dispatch' || env.GITHUB_REF !== 'refs/heads/homolog' || env.APPLY_CONFIRMATION !== 'APLICAR HOMOLOG') {
    throw new Error('Apply requires manual dispatch on homolog and APLICAR HOMOLOG');
  }
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
    console.log('Manual request and protected homolog-apply Environment verified.');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
