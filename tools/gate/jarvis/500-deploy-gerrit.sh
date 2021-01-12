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

function generate_ssh_host_key_override() {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/etc/ssh"
  ssh-keygen -A -f "${work_dir}"
  local output_file
  output_file="$(mktemp -d)/gerrit-host-rsa-key.yaml"
  tee "${output_file}" <<EOF
gerrit:
  service:
    ssh:
      rsaKey: |-
$(awk  '{ print "        " $0 }' "${work_dir}/etc/ssh/ssh_host_rsa_key")
EOF
  export ssh_host_key_override="${output_file}"
}
generate_ssh_host_key_override

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=gerrit \
    gerrit \
    "${gerrit_source}/helm-charts/gerrit" \
    --values="${ssh_host_key_override}" \
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