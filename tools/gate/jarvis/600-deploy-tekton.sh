#!/bin/bash
set -ex

for chart in tekton-pipelines tekton-triggers tekton-dashboard; do
  # shellcheck disable=SC2046
  helm upgrade \
    --create-namespace \
    --install \
    --namespace=tekton-pipelines \
    "${chart}" \
    "./charts/${chart}" \
    $(./tools/deployment/common/get-values-overrides.sh "${chart}")
done

./tools/deployment/common/wait-for-pods.sh tekton-pipelines