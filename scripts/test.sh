#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
consumer_dir="${repo_dir}/tests/consumer"
output_dir="$(mktemp -d)"
trap 'rm -rf "${output_dir}"' EXIT

helm lint "${repo_dir}" --strict
helm dependency build "${consumer_dir}"
helm lint "${consumer_dir}" --strict

helm template phase1 "${consumer_dir}" --namespace phase1 >"${output_dir}/default.yaml"
helm template phase1 "${consumer_dir}" --namespace phase1 \
  -f "${repo_dir}/tests/values/configured.yaml" >"${output_dir}/configured.yaml"

for example in "${consumer_dir}"/examples/*.yaml; do
  example_name="$(basename "${example}" .yaml)"
  helm template "${example_name}" "${consumer_dir}" --namespace phase1 \
    -f "${example}" >"${output_dir}/${example_name}.yaml"
done

default_render="${output_dir}/default.yaml"
configured_render="${output_dir}/configured.yaml"

test "$(grep -Ec '^[[:space:]]+app: phase1-consumer$' "${default_render}")" -eq 3
! grep -q 'automountServiceAccountToken:' "${default_render}"
! grep -q 'revisionHistoryLimit:' "${default_render}"
! grep -q 'securityContext:' "${default_render}"

grep -q '^  revisionHistoryLimit: 4$' "${configured_render}"
test "$(grep -c 'automountServiceAccountToken: false' "${configured_render}")" -eq 3
grep -q 'seccompProfile:' "${configured_render}"
grep -q 'allowPrivilegeEscalation: false' "${configured_render}"

for invalid_values in invalid-selector invalid-automount invalid-revision; do
  if helm template phase1 "${consumer_dir}" --namespace phase1 \
    -f "${repo_dir}/tests/values/${invalid_values}.yaml" >"${output_dir}/${invalid_values}.out" 2>&1; then
    echo "expected ${invalid_values}.yaml to fail" >&2
    exit 1
  fi
done

echo "Phase 1 library contract tests passed with $(helm version --short)."
