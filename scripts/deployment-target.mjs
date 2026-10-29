// Explicit targets: a branch can never select the other environment's state.
export const targets = Object.freeze({
  homolog: Object.freeze({ branch: 'homolog', directory: 'environments/homolog',
    applyEnvironment: 'homolog-apply', stateKey: 'homolog/terraform.tfstate', tfvarsSecret: 'TFVARS_HOMOLOG' }),
  production: Object.freeze({ branch: 'main', directory: 'environments/production',
    applyEnvironment: 'production-apply', stateKey: 'production/terraform.tfstate', tfvarsSecret: 'TFVARS_PRODUCTION' }),
});
export function deploymentTarget(env) {
  const name = env.GITHUB_REF === 'refs/heads/homolog' ? 'homolog'
    : env.GITHUB_REF === 'refs/heads/main' ? 'production' : null;
  if (!name || (env.DEPLOY_ENVIRONMENT && env.DEPLOY_ENVIRONMENT !== name)) {
    throw new Error('Deployment branch/environment mismatch');
  }
  return { name, ...targets[name] };
}
export function checkRepository(env) {
  const allowed = ['felipevrds/techChallengePosTech-k8s-infra', 'FernandoGreco/techChallengePosTech-k8s-infra'];
  const configured = env.INFRA_DEPLOY_REPOSITORY || allowed[0];
  if (!allowed.includes(configured) || env.GITHUB_REPOSITORY !== configured) {
    throw new Error('Repository is not explicitly authorized for infrastructure operations');
  }
}
