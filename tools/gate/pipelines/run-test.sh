#!/bin/bash

set -eux

# executes the harbor tests
./tools/gate/harbor/300-test.sh

# executes the tekton tests
./tools/gate/tekton/300-test.sh

# performs AIO integration tests
CREDENTIAL="--username=admin --password=Harbor12345"

# Downloads the cli helm push plugin with chartmuseum
helm plugin install https://github.com/chartmuseum/helm-push

# Downloads a chartmuseum tarball and upload it to a newly created repo in harbor
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm pull stable/chartmuseum

HARBORIP=$(kubectl -n harbor get svc harbor-harbor-core -ojsonpath='{.spec.clusterIP}')
helm repo add myrepo http://$HARBORIP/chartrepo $CREDENTIAL
helm push $CREDENTIAL $(ls chartmuseum*.tgz) myrepo
helm repo update
helm search repo --regexp myrepo/*
