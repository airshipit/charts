#!/bin/bash
set -ex

make -C ./charts harbor

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=harbor \
    harbor \
    ./charts/harbor \
    $(./tools/deployment/common/get-values-overrides.sh harbor)

./tools/deployment/common/wait-for-pods.sh harbor

helm -n harbor test harbor --logs

function validate() {
    helm plugin update push || helm plugin install https://github.com/chartmuseum/helm-push

    # Downloads a chartmuseum tarball and upload it to a newly created repo in harbor
    helm repo add stable https://charts.helm.sh/stable
    local source_chart_dir
    source_chart_dir="$(mktemp -d)"
    helm pull stable/chartmuseum --destination "${source_chart_dir}"
    helm repo add jarvis-harbor "https://harbor-core.jarvis.local/chartrepo" --username=admin --password=Harbor12345
    helm push --username=admin --password=Harbor12345 "$(ls "${source_chart_dir}"/chartmuseum*.tgz)" jarvis-harbor
    helm repo update
    local chart_dir
    chart_dir="$(mktemp -d)"
    helm pull jarvis-harbor/library/chartmuseum --destination "${chart_dir}"

    #TODO(staceyF) Put this into appropriate jarvis-system tasks
    kubectl create ns development-pipeline
    kubectl create secret generic harbor-ca --from-file=harbor-ca=/etc/jarvis/certs/ca/ca.pem -n development-pipeline
    #NOTE Will not be required once Harbor is backed by LDAP
    kubectl create secret generic harbor-basic-auth --from-literal=username='admin' --from-literal=password='Harbor12345' -n development-pipeline
    kubectl create secret docker-registry harbor-docker-auth --docker-username=admin --docker-password=Harbor12345 --docker-email=example@gmail.com --docker-server=harbor-core.jarvis.local -n development-pipeline
    #TODO(staceyF) Put this into appropriate jarvis-project tasks
    curl -X POST "https://harbor-core.jarvis.local/api/v2.0/projects" -H "accept: application/json" -H "X-Request-Id: 12345" -H "authorization: Basic YWRtaW46SGFyYm9yMTIzNDU=" -H "Content-Type: application/json" -d "{ \"project_name\": \"test\", \"public\": true, \"metadata\": { \"auto_scan\": \"true\" }}"
    # Tests that we can upload an image
    sudo -E docker login harbor-core.jarvis.local --username admin --password Harbor12345
    sudo -E docker pull debian:buster-slim
    sudo -E docker tag debian:buster-slim harbor-core.jarvis.local/library/debian:buster-slim
    sudo -E docker push harbor-core.jarvis.local/library/debian:buster-slim

    # Test that we can download an image
    sudo -E docker rmi harbor-core.jarvis.local/library/debian:buster-slim
    sudo -E docker pull harbor-core.jarvis.local/library/debian:buster-slim
}

validate
