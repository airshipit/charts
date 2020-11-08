#!/bin/bash
set -ux

export PARALLELISM_FACTOR=2

function get_namespaces {
  kubectl get namespaces -o name | awk -F '/' '{ print $NF }'
}

function get_pods () {
  NAMESPACE=$1
  kubectl get pods -n ${NAMESPACE} -o name | awk -F '/' '{ print $NF }' | xargs -L1 -P${PARALLELISM_FACTOR} -I {} echo ${NAMESPACE} {}
}

export -f get_pods

function get_pod_logs () {
  NAMESPACE=${1% *}
  POD=${1#* }
  INIT_CONTAINERS=$(kubectl get pod $POD -n ${NAMESPACE} -o json | jq -r '.spec.initContainers[]?.name')
  CONTAINERS=$(kubectl get pod $POD -n ${NAMESPACE} -o json | jq -r '.spec.containers[].name')
  for CONTAINER in ${INIT_CONTAINERS} ${CONTAINERS}; do
    echo "${NAMESPACE}/${POD}/${CONTAINER}"
    mkdir -p "${LOGDIR}/pod-logs/${NAMESPACE}/${POD}"
    kubectl logs ${POD} -n ${NAMESPACE} -c ${CONTAINER} > "${LOGDIR}/pod-logs/${NAMESPACE}/${POD}/${CONTAINER}.txt"
  done
}

export -f get_pod_logs

get_namespaces | \
  xargs -r -n 1 -P ${PARALLELISM_FACTOR} -I {} bash -c 'get_pods "$@"' _ {} | \
  xargs -r -n 2 -P ${PARALLELISM_FACTOR} -I {} bash -c 'get_pod_logs "$@"' _ {}
