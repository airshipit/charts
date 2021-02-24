#!/bin/bash
set -ex

# escape commas in no_proxy because Helm tries to split the value on commas
# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=jarvis-system \
    --set proxy.http_proxy="$http_proxy" \
    --set proxy.https_proxy="$https_proxy" \
    --set proxy.no_proxy="$(echo $no_proxy | sed "s/,/\\\,/g")" \
    --set proxy.internal_certs_dir="$PWD/tools/gate/jarvis/ubuntu-base/internal-certs/" \
    jarvis-system \
    "./charts/jarvis-system" \
    $(./tools/deployment/common/get-values-overrides.sh jarvis-system)

./tools/deployment/common/wait-for-pods.sh jarvis-system