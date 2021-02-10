#!/bin/bash
set -ex

cd ./tools/images
sudo make build IMAGE_FULLNAME=standard-container:1.0

cd ../../charts
helm upgrade --install development-pipeline -n development-pipeline ./development-pipeline
kubectl apply -n development-pipeline -f ./development-pipeline/config_map.yaml.example
kubectl create -n development-pipeline -f ./development-pipeline/pipelinerun-validation.yaml
../tools/deployment/common/wait-for-pipelinerun.sh development-pipeline development-pipeline
