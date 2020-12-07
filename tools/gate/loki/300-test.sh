#!/bin/bash

set -eux

NS="loki-stack"
GNS="grafana"

# Run helm test and check the loki runs
helm test loki -n $NS
kubectl --namespace $NS get pod

# Run helm test and check the grafana runs
helm test grafana -n $GNS
kubectl --namespace $GNS get pod
