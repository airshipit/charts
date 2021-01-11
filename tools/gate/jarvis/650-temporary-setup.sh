#!/bin/bash
set -ex

#TODO(staceyF) Put this into appropriate jarvis-system tasks
kubectl create ns development-pipeline || true
kubectl create secret generic harbor-ca --from-file=harbor-ca=/etc/jarvis/certs/ca/ca.pem -n development-pipeline || true
kubectl create secret generic kubeconfig-secret --from-file=kubeconfig=$HOME/.kube/config -n development-pipeline || true
#NOTE Will not be required once Harbor is backed by LDAP
kubectl create secret generic harbor-basic-auth --from-literal=username='admin' --from-literal=password='Harbor12345' -n development-pipeline || true
kubectl create secret docker-registry harbor-docker-auth --docker-username=admin --docker-password=Harbor12345 --docker-email=example@gmail.com --docker-server=harbor-core.jarvis.local -n development-pipeline || true
#TODO(staceyF) Put this into appropriate jarvis-project tasks
curl -X POST "https://harbor-core.jarvis.local/api/v2.0/projects" -H "accept: application/json" -H "X-Request-Id: 12345" -H "authorization: Basic YWRtaW46SGFyYm9yMTIzNDU=" -H "Content-Type: application/json" -d "{ \"project_name\": \"mongodb-staging\", \"public\": true, \"metadata\": { \"auto_scan\": \"true\" }}" || true
curl -X POST "https://harbor-core.jarvis.local/api/v2.0/projects" -H "accept: application/json" -H "X-Request-Id: 12345" -H "authorization: Basic YWRtaW46SGFyYm9yMTIzNDU=" -H "Content-Type: application/json" -d "{ \"project_name\": \"mongodb\", \"public\": true, \"metadata\": { \"auto_scan\": \"true\" }}" || true

#NOTE This is temporary to trigger and validate that the development-pipeline is working prior to being refactored.

cd ./tools/images
sudo make build IMAGE_FULLNAME=standard-container:1.0

cd ../../charts
helm upgrade --install development-pipeline -n development-pipeline ./development-pipeline

kubectl apply -n development-pipeline -f ./development-pipeline/config_map.yaml.example

kubectl create -n development-pipeline -f ./development-pipeline/pipelinerun-validation.yaml

../tools/deployment/common/wait-for-pipelinerun.sh development-pipeline development-pipeline
