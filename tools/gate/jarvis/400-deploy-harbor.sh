#!/bin/bash
set -ex
helm repo add harbor https://helm.goharbor.io

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=harbor \
    harbor \
    harbor/harbor \
    $(./tools/deployment/common/get-values-overrides.sh harbor)

./tools/deployment/common/wait-for-pods.sh harbor

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

    # Tests that we can upload an image
    sudo -E docker login harbor-core.jarvis.local --username admin --password Harbor12345
    sudo -E docker pull debian:buster-slim
    sudo -E docker tag debian:buster-slim harbor-core.jarvis.local/library/debian:buster-slim
    sudo -E docker push harbor-core.jarvis.local/library/debian:buster-slim
}

validate
