#!/bin/bash
set -ex
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

# NOTE: This chart creates objects in gatekeeper-system
# shellcheck disable=SC2046
helm upgrade \
    --install \
    --namespace=kube-system \
    gatekeeper \
    gatekeeper/gatekeeper \
    $(./tools/deployment/common/get-values-overrides.sh gatekeeper)

./tools/deployment/common/wait-for-pods.sh gatekeeper-system