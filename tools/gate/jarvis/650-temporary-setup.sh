#!/bin/bash
set -ex

#TODO(staceyF) Put this into appropriate jarvis-system tasks
kubectl create ns development-pipeline || true
kubectl create secret generic harbor-ca --from-file=harbor-ca=/etc/jarvis/certs/ca/ca.pem -n development-pipeline || true
kubectl create secret generic kubeconfig-secret --from-file=kubeconfig=$HOME/.kube/config -n development-pipeline || true
#NOTE Will not be required once Harbor is backed by LDAP
kubectl create secret generic harbor-basic-auth --from-literal=username='admin' --from-literal=password='Harbor12345' -n development-pipeline || true
kubectl create secret docker-registry harbor-docker-auth --docker-username=admin --docker-password=Harbor12345 --docker-email=example@gmail.com --docker-server=harbor-core.jarvis.local -n development-pipeline || true
