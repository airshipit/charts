#!/bin/bash

set -eux

NS="tekton-pipelines"

kubectl create ns $NS

for ele in tekton-pipelines tekton-triggers tekton-dashboard; do
  helm upgrade --install $ele ./charts/$ele --namespace $NS
done

kubectl wait --for=condition=ready pod --timeout=120s --namespace $NS --all

kubectl --namespace $NS get pod
