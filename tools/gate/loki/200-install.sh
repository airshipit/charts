#!/bin/bash
set -eux

NS="loki-stack"
GNS="grafana"

kubectl create ns $NS || true
kubectl create ns $GNS || true
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# install loki-stack with Loki and Promtail from Grafana helm charts repo
helm upgrade --install loki grafana/loki-stack --namespace $NS -f ./tools/gate/loki/loki-stack-values.yaml
kubectl wait --for=condition=ready pod --timeout=600s --namespace $NS --all
kubectl --namespace $NS get pod

# install Grafana from Grafana helm charts repo
helm upgrade --install grafana grafana/grafana --namespace $GNS -f ./tools/gate/loki/grafana-values.yaml
kubectl wait --for=condition=ready pod --timeout=600s --namespace $GNS --all
kubectl --namespace $GNS get pod
