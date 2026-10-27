import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Never emit attribute values, outputs, user-data or full plan JSON.
export function summarizePlan(plan) {
  if (!plan || !Array.isArray(plan.resource_changes ?? [])) throw new Error('Invalid plan format');
  const counts = { create: 0, update: 0, delete: 0, replace: 0, read: 0, unchanged: 0 };
  const resources = [];
  for (const resource of plan.resource_changes ?? []) {
    const actions = resource.change?.actions;
    if (!Array.isArray(actions) || actions.some(a => !['no-op', 'create', 'update', 'delete', 'read'].includes(a))) {
      throw new Error('Unknown Terraform action; review required');
    }
    if (resource.mode === 'data') { counts.read++; continue; }
    if (!actions.includes('no-op')) {
      const keys = new Set([...Object.keys(resource.change.before ?? {}), ...Object.keys(resource.change.after ?? {})]);
      resources.push({
        address: /^[a-zA-Z0-9_.\[\]"-]+$/.test(resource.address ?? '') ? resource.address : '(resource address withheld)',
        actions,
        changed_fields: [...keys].filter(key => /^[a-zA-Z0-9_]+$/.test(key) && JSON.stringify(resource.change.before?.[key]) !== JSON.stringify(resource.change.after?.[key])),
      });
    }
    if (actions.includes('delete') && actions.includes('create')) counts.replace++;
    else if (actions.includes('delete')) counts.delete++;
    else if (actions.includes('create')) counts.create++;
    else if (actions.includes('update')) counts.update++;
    else counts.unchanged++;
  }
  return { ...counts, destructive: counts.delete > 0 || counts.replace > 0, resources };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const summary = summarizePlan(JSON.parse(readFileSync(0, 'utf8')));
    console.log(JSON.stringify(summary));
    // Infrastructure destruction/replacement needs a separate reviewed procedure.
    if (summary.destructive) process.exitCode = 2;
  } catch { console.error('Plan cannot be safely summarized; details withheld'); process.exitCode = 1; }
}
