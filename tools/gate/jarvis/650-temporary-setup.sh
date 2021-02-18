#!/bin/bash
set -ex

ldap_username="jarvis"
ldap_password="password"
ldap_email="jarvis@cluster.local"
harbor_core="harbor-core.jarvis.local" #Defined in harbor overrides, TODO, extract from there

#TODO(staceyF) Put this into appropriate jarvis-system tasks
kubectl create ns development-pipeline || true
kubectl create secret generic harbor-ca --from-file=harbor-ca=/etc/jarvis/certs/ca/ca.pem -n development-pipeline || true
kubectl create secret generic kubeconfig-secret --from-file=kubeconfig=$HOME/.kube/config -n development-pipeline || true
#NOTE Will not be required once Harbor is backed by LDAP
kubectl create secret generic harbor-basic-auth --from-literal=username=$ldap_username --from-literal=password=$ldap_password -n development-pipeline || true
kubectl create secret docker-registry harbor-docker-auth --docker-username=$ldap_username --docker-password=$ldap_password --docker-email=$ldap_email --docker-server=$harbor_core -n development-pipeline || true

cd ./tools/gate/jarvis/standard-container
sudo docker build -t standard-container:1.0 .