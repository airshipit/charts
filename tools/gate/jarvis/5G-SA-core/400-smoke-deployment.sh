#!/bin/bash
set -ex

: "${kube_namespace:="open5gs"}"

for network_function in `find ./tools/gate/jarvis/5G-SA-core -maxdepth 1 -type d | tail -n +2 | awk -F '/' '{ print $NF }'`; do
  helm upgrade \
    --create-namespace \
    --install \
    --namespace="${kube_namespace}" \
    "${network_function}" \
    "./tools/gate/jarvis/5G-SA-core/${network_function}/charts/${network_function}"
done

./tools/deployment/common/wait-for-pods.sh "${kube_namespace}"