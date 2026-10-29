#!/usr/bin/env bash
set -euo pipefail
[[ "${EXPECTED_AWS_ACCOUNT_ID:-}" =~ ^[0-9]{12}$ ]] || { echo 'Configure AWS_ACCOUNT_ID.' >&2; exit 1; }
for credential in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
  [[ -n "${!credential:-}" ]] || { echo 'Configure all three temporary AWS Academy credentials.' >&2; exit 1; }
done
CURRENT_ACCOUNT="$(aws sts get-caller-identity --query Account --output text --cli-connect-timeout 5 --cli-read-timeout 10)"
[[ "$CURRENT_ACCOUNT" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || { echo 'AWS account mismatch; stopping.' >&2; exit 1; }
echo 'AWS identity matches expected account.'
