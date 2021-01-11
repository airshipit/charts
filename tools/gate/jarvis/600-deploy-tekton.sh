#!/bin/bash
set -ex

for chart in tekton-pipelines tekton-triggers tekton-dashboard; do
  # shellcheck disable=SC2046
  helm upgrade \
    --create-namespace \
    --install \
    --namespace=tekton-pipelines \
    "${chart}" \
    "./charts/${chart}" \
    $(./tools/deployment/common/get-values-overrides.sh "${chart}")
done

function get_yq() {
  version=$(curl --silent "https://api.github.com/repos/mikefarah/yq/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  sudo -E curl -L -o "/usr/local/bin/yq" "https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_amd64"
  sudo -E chmod +x "/usr/local/bin/yq"
  ls "/usr/local/bin/yq"
}

./tools/deployment/common/wait-for-pods.sh tekton-pipelines

function validate() {

  # if we are using the proxy we should place that into the template
  if [ -n "${HTTP_PROXY}" ]; then
    get_yq

    # Note: This assume syntax of yq >= 4.x
    yq eval '(.spec.resourcetemplates[].spec.params[] | select(.name=="httpProxy")).value |= env(HTTP_PROXY)' -i ./tools/gate/jarvis/resources/tekton/yaml/triggertemplates/triggertemplate.yaml
    yq eval '(.spec.resourcetemplates[].spec.params[] | select(.name=="httpsProxy")).value |= env(HTTPS_PROXY)' -i ./tools/gate/jarvis/resources/tekton/yaml/triggertemplates/triggertemplate.yaml
    yq eval '(.spec.resourcetemplates[].spec.params[] | select(.name=="noProxy")).value |= env(NO_PROXY)' -i ./tools/gate/jarvis/resources/tekton/yaml/triggertemplates/triggertemplate.yaml
  fi

  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/secret.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/serviceaccount.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/clustertriggerbinding-roles
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/triggerbinding-roles
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/triggertemplates/triggertemplate.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/triggerbindings/triggerbinding.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/triggerbindings/triggerbinding-message.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/eventlisteners/eventlistener.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/example-pipeline.yaml

  # Install the pipeline
  kubectl -n tekton-pipelines wait --for=condition=Ready pod --timeout=120s --all

  # Define creds to use for gerrit.
  ldap_username="jarvis"
  ldap_password="password"

  # Create repo for Jarvis sanity testing
  ssh -p 29418 ${ldap_username}@gerrit.jarvis.local gerrit create-project jarvis-sanity --submit-type MERGE_IF_NECESSARY --owner Administrators --empty-commit

  # Configure repo webhook
  jarvis_sanity_repo=$(mktemp -d)
  pushd "${jarvis_sanity_repo}"
  git init
  git remote add origin ssh://${ldap_username}@gerrit.jarvis.local:29418/jarvis-sanity.git
  git fetch origin refs/meta/config:refs/remotes/origin/meta/config
  git checkout meta/config
  tee --append project.config <<EOF
[plugin "webhooks"]
    connectionTimeout = 3000
    maxTries = 300
    retryInterval = 2000
    socketTimeout = 2500
    threadPoolSize = 3
EOF
  tee webhooks.config <<EOF
[remote "Tekton"]
    url = http://el-listener.tekton-pipelines.svc.cluster.local:8080/
    maxTries = 3
    sslVerify = false
    event = patchset-created
    event = patchset-updated
EOF
  git add .
  git commit -asm "Create Add PS Webhook Config"
  git push origin HEAD:refs/meta/config
  popd

  # Create PS to repo to test webhook
  jarvis_sanity_repo=$(mktemp -d)
  git clone ssh://${ldap_username}@gerrit.jarvis.local:29418/jarvis-sanity.git "${jarvis_sanity_repo}"
  pushd "${jarvis_sanity_repo}"
  tee .gitreview <<EOF
[gerrit]
host=gerrit.jarvis.local
port=29418
project=jarvis-sanity.git
EOF
  git review -s
  git add .gitreview
  git commit -asm "Add .gitreview"
  git review

  # Sleep for 5s to give time for webhook to fire, and be responded to
  sleep 5

  # Ensure the run is successful
  kubectl -n tekton-pipelines wait --for=condition=Succeeded pipelineruns --timeout=120s --all

  # Check the pipeline runs
  kubectl -n tekton-pipelines get pipelinerun
}

validate
