#!/bin/bash
set -ex

make -C ./charts loki

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=loki \
    loki \
    ./charts/loki \
    $(./tools/deployment/common/get-values-overrides.sh loki)

./tools/deployment/common/wait-for-pods.sh loki

# TODO(dustinspecker): remove this if condition and run loki test behind proxy
# loki pod's container downloads jq and curl, which won't work
# since the proxies are not configured for the pod, so skip test loki test for now
# when proxy is defined
if [ -z "$http_proxy" ]; then
     helm -n loki test loki --logs
fi
