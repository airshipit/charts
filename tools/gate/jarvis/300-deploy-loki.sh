#!/bin/bash
set -ex

cd ./charts/loki
helm dep up
cd -

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=loki \
    loki \
    ./charts/loki \
    $(./tools/deployment/common/get-values-overrides.sh loki)

./tools/deployment/common/wait-for-pods.sh loki

helm -n loki test loki --logs
