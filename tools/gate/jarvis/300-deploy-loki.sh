#!/bin/bash
set -ex

helm repo add grafana https://grafana.github.io/helm-charts

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=loki \
    loki \
    grafana/loki-stack \
    $(./tools/deployment/common/get-values-overrides.sh loki)

./tools/deployment/common/wait-for-pods.sh loki