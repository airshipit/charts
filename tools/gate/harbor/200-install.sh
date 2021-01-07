#!/bin/bash
set -eux

: ${EXTRA_HELM_ARGS_HARBOR}:="$(./tools/deployment/common/get-values-overrides.sh harbor)"}

NS="harbor"
kubectl create ns $NS
helm upgrade --install harbor ./charts/harbor \
  --namespace $NS \
  --values=${EXTRA_HELM_ARGS_HARBOR}

./tools/deployment/common/wait-for-pods.sh $NS
helm status harbor

helm test harbor -n $NS

#kubectl --namespace $NS get pod
