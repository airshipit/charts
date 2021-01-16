#!/bin/bash
set -ex

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=jarvis-system \
    jarvis-system \
    "./charts/jarvis-system" \
    $(./tools/deployment/common/get-values-overrides.sh jarvis-system)

./tools/deployment/common/wait-for-pods.sh jarvis-system