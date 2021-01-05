#!/bin/bash
set -ex

gerrit_source=$(mktemp -d)
repo_sha="251041b192ef8acf1963d747482126d0e9e66e75"
repo_remote="https://gerrit.googlesource.com/k8s-gerrit"

function get_repo() {
    pushd "${1}"
    git init
    git remote add origin "${2}"
    git fetch origin --depth=1 "${3}"
    git reset --hard FETCH_HEAD
    popd
}
get_repo "${gerrit_source}" "${repo_remote}" "${repo_sha}"

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=gerrit \
    gerrit \
    "${gerrit_source}/helm-charts/gerrit" \
    $(./tools/deployment/common/get-values-overrides.sh gerrit)

./tools/deployment/common/wait-for-pods.sh gerrit

#TODO(portdirect): Update chart to support SSH via TCP ingress, in addition to being able to spec nodeport
kubectl patch -n gerrit svc gerrit-gerrit-service --patch '{
  "spec": {
    "ports": [
      {
        "name": "ssh",
        "nodePort": 29418,
        "port": 29418,
        "protocol": "TCP",
        "targetPort": 29418
      }
    ]
  }
}'