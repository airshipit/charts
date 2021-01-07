#!/bin/bash
set -eux

: ${EXTRA_HELM_ARGS_LOKI_STACK}:="$(./tools/deployment/common/get-values-overrides.sh loki)"}
: ${EXTRA_HELM_ARGS_GRAFANA}:="$(./tools/deployment/common/get-values-overrides.sh grafana)"}
NS="loki-stack"
GNS="grafana"

kubectl create ns $NS || true
kubectl create ns $GNS || true
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# install loki-stack with Loki and Promtail from Grafana helm charts repo
helm upgrade --install loki grafana/loki-stack --namespace $NS $EXTRA_HELM_ARGS_LOKI_STACK
./tools/deployment/common/wait-for-pods.sh $NS

helm status loki

# install Grafana from Grafana helm charts repo
helm upgrade --install grafana grafana/grafana --namespace $GNS $EXTRA_HELM_ARGS_GRAFANA
./tools/deployment/common/wait-for-pods.sh $GNS

helm status grafana