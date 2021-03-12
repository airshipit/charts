#!/bin/bash
set -ex

# development-pipeline namespace is needed by the mongodb bitnami helm release
kubectl create ns development-pipeline || true

cd ./tools/gate/jarvis/standard-container
sudo docker build -t standard-container:1.0 .
