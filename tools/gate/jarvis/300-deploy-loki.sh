#!/bin/bash
set -ex

make -C ./charts loki

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=loki \
    loki \
    ./charts/loki \
    $(./tools/deployment/common/get-values-overrides.sh loki)

./tools/deployment/common/wait-for-pods.sh loki

# todo(dustinspecker): create a pull request for Loki Helm chart
# to provide proxy configuration to prevent having to modify the
# configmap. Then provide proxy configuration as overrides to the
# `helm upgrade` command above.
proxy_export="\
    export HTTP_PROXY=\"$HTTP_PROXY\"\n\
    export HTTPS_PROXY=\"$HTTPS_PROXY\"\n\
    export NO_PROXY=\"$NO_PROXY,\$LOKI_SERVICE\"\n\
    export http_proxy=\"$http_proxy\"\n\
    export https_proxy=\"$https_proxy\"\n\
    export no_proxy=\"$no_proxy,\$LOKI_SERVICE\"\
"

configmap_yaml="$(mktemp)"

kubectl get configmap loki-loki-stack-test \
    --namespace loki \
    --output yaml \
> "$configmap_yaml"

# install gawk because older versions of awk and alternatives such as mawk
# don't support inplace
sudo -E apt-get install gawk --yes

# prepend proxy_export only for the first match of LOKI_URI=
# This enables the script to be idempotent and prevent modifying the
# last-applied-configuration annotation and breaking the YAML format.
gawk --assign proxy_export="$proxy_export" \
    --include inplace \
    '/LOKI_URI=/ && !matched { print proxy_export ; matched=1 } 1' "$configmap_yaml"

kubectl apply --filename "$configmap_yaml"

helm -n loki test loki --logs
