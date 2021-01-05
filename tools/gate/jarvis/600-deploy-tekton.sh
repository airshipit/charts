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

./tools/deployment/common/wait-for-pods.sh tekton-pipelines

function validate() {
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/secret.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/serviceaccount.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/clustertriggerbinding-roles
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/role-resources/triggerbinding-roles
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/triggertemplates/triggertemplate.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/triggerbindings/triggerbinding.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/triggerbindings/triggerbinding-message.yaml
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/eventlisteners/eventlistener.yaml

  kubectl -n tekton-pipelines wait --for=condition=Ready pod --timeout=120s --all

  # Install the pipeline
  kubectl -n tekton-pipelines apply -f ./tools/gate/jarvis/resources/tekton/yaml/example-pipeline.yaml
  kubectl -n tekton-pipelines wait --for=condition=Ready pod --timeout=120s --all

  kubectl get po -A

  # Trigger the sample github pipeline
  local listener_ip
  listener_ip="$(kubectl -n tekton-pipelines get svc el-listener -o 'jsonpath={.spec.clusterIP}')"
  curl -X POST \
    "http://${listener_ip}:8080" \
    -H 'Content-Type: application/json' \
    -H 'X-Hub-Signature: sha1=2da37dcb9404ff17b714ee7a505c384758ddeb7b' \
    -d '{"repository":{"url": "https://github.com/tektoncd/triggers.git"}}'

  # Ensure the run is successful
  kubectl -n tekton-pipelines wait --for=condition=Succeeded pipelineruns --timeout=120s --all

  # Check the pipeline runs
  kubectl -n tekton-pipelines get pipelinerun
}

validate