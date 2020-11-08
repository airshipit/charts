#!/bin/bash
set -eux

NS="harbor"
kubectl create ns $NS
helm upgrade --install harbor ./charts/harbor --namespace $NS
kubectl wait --for=condition=ready pod --timeout=600s --namespace $NS --all
helm test harbor -n $NS
kubectl --namespace $NS get pod
