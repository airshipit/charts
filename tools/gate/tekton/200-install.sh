#!/bin/bash

set -eux

NS="tekton-pipelines"

kubectl create ns $NS

for ele in tekton-pipelines tekton-triggers tekton-dashboard; do
  EXTRA_HELM_ARGS="$(./tools/deployment/common/get-values-overrides.sh $ele)"
  helm upgrade --install $ele ./charts/$ele --namespace $NS $EXTRA_HELM_ARGS
done

./tools/deployment/common/wait-for-pods.sh $NS
helm status -n $NS tekton-pipelines
helm status -n $NS tekton-triggers
helm status -n $NS tekton-dashboard

kubectl --namespace $NS get pod
