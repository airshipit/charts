#!/bin/bash
set -ex

# NOTE(lamt): Runs this script in the root directory of this repo.
: ${NAMESPACE:="tekton-pipelines"}
: ${CHART_ROOT_PATH:="./charts"}

# deploys a Kubernetes cluster
# ./tools/gate/deploy-k8s.sh

# creates namespace
kubectl create namespace $NAMESPACE || true

# TODO(lamt): Needs an PV/C provider - NFS

# deploys harbor
helm upgrade --install harbor ${CHART_ROOT_PATH}/harbor \
  --namespace=$NAMESPACE \
  ${EXTRA_HELM_ARGS_TEKTON_HARBOR}

# deploys tekton
helm upgrade --install tekton-pipelines ${CHART_ROOT_PATH}/tekton-pipelines \
  --namespace=$NAMESPACE \
  ${EXTRA_HELM_ARGS_TEKTON_PIPELINES}

helm upgrade --install tekton-triggers ${CHART_ROOT_PATH}/tekton-triggers \
  --namespace=$NAMESPACE \
  ${EXTRA_HELM_ARGS_TEKTON_TRIGGERS}

helm upgrade --install tekton-dashboard ${CHART_ROOT_PATH}/tekton-dashboard \
  --namespace=$NAMESPACE \
  ${EXTRA_HELM_ARGS_TEKTON_DASHBOARD}

# waits for the pods to get ready
kubectl --namespace $NAMESPACE wait --for=condition=ready pod --timeout=600s --all
