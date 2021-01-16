#!/bin/bash
set -ex

function generate_gerrit_creds_override() {
  local output_file
  output_file="$(mktemp -d)/gerrit-host-rsa-key.yaml"
  tee "${output_file}" <<EOF
params:
  gerrit:
    user: jarvis
    password: password
    ssh_key: |
$(awk  '{ print "      " $0 }' "${HOME}/.ssh/id_rsa")
EOF
  export gerrit_creds_override="${output_file}"
}
generate_gerrit_creds_override

jarvis_project=jarvis-project

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=jarvis-projects \
    "${jarvis_project}" \
    "./charts/jarvis-project" \
    --values="${gerrit_creds_override}" \
    $(./tools/deployment/common/get-values-overrides.sh jarvis-project)

./tools/deployment/common/wait-for-pods.sh jarvis-projects

sleep 60

# Define creds to use for gerrit.
ldap_username="jarvis"

# Create PS to repo to test jarvis
jarvis_sanity_repo=$(mktemp -d)
git clone ssh://${ldap_username}@gerrit.jarvis.local:29418/${jarvis_project}.git "${jarvis_sanity_repo}"
pushd "${jarvis_sanity_repo}"
tee .gitreview <<EOF
[gerrit]
host=gerrit.jarvis.local
port=29418
project=${jarvis_project}.git
EOF
git review -s
git add .gitreview
git commit -asm "Add .gitreview"
git review
popd

# Check jarvis pipeline run
end=$(date +%s)
timeout="900"
end=$((end + timeout))
while true; do
  result="$(curl -L https://gerrit.jarvis.local/changes/1/revisions/1/checks | tail -1 | jq -r .[].state)"
  [ $result == "SUCCESSFUL" ] && break || true
  sleep 5
  now=$(date +%s)
  if [ $now -gt $end ] ; then
    echo "Pipeline failed to complete $timeout seconds"
    exit -1
  fi
done