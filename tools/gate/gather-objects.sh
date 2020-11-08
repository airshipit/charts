#!/bin/bash
set -ux

export PARALLELISM_FACTOR=2
export OBJECT_TYPE=node,clusterrole,clusterrolebinding,storageclass,namespace,crd
export NS_OBJECT_TYPE=configmaps,cronjobs,daemonsets,deployment,endpoints,ingresses,jobs,networkpolicies,pods,podsecuritypolicies,persistentvolumeclaims,rolebindings,roles,secrets,serviceaccounts,services,statefulsets

function get_namespaces {
  kubectl get namespaces -o name | awk -F '/' '{ print $NF }'
}

function list_objects {
  printf ${OBJECT_TYPE} | xargs -d ',' -I {} -P${PARALLELISM_FACTOR} -n1 bash -c 'echo "$@"' _ {}
}

function name_objects {
  export OBJECT=$1
  kubectl get ${OBJECT} -o name | xargs -L1 -I {} -P${PARALLELISM_FACTOR} -n1 bash -c 'echo "${OBJECT} ${1#*/}"' _ {}
}

function get_objects {
  input=($1)
  export OBJECT=${input[0]}
  export NAME=${input[1]#*/}
  echo "${OBJECT}/${NAME}"
  DIR="${LOGDIR}/objects/cluster/${OBJECT}"
  mkdir -p ${DIR}
  kubectl get ${OBJECT} ${NAME} -o yaml > "${DIR}/${NAME}.yaml"
  kubectl describe ${OBJECT} ${NAME} > "${DIR}/${NAME}.txt"
}

function list_namespaced_objects {
  export NAMESPACE=$1
  printf ${NS_OBJECT_TYPE} | xargs -d ',' -I {} -P${PARALLELISM_FACTOR} -n1 bash -c 'echo "${NAMESPACE} $@"' _ {}
}

function name_namespaced_objects {
  input=($1)
  export NAMESPACE=${input[0]}
  export OBJECT=${input[1]}
  kubectl get -n ${NAMESPACE} ${OBJECT} -o name | xargs -L1 -I {} -P${PARALLELISM_FACTOR} -n1 bash -c 'echo "${NAMESPACE} ${OBJECT} $@"' _ {}
}

function get_namespaced_objects () {
  input=($1)
  export NAMESPACE=${input[0]}
  export OBJECT=${input[1]}
  export NAME=${input[2]#*/}
  echo "${NAMESPACE}/${OBJECT}/${NAME}"
  DIR="${LOGDIR}/objects/namespaced/${NAMESPACE}/${OBJECT}"
  mkdir -p ${DIR}
  kubectl get -n ${NAMESPACE} ${OBJECT} ${NAME} -o yaml > "${DIR}/${NAME}.yaml"
  kubectl describe -n ${NAMESPACE} ${OBJECT} ${NAME} > "${DIR}/${NAME}.txt"
}

export -f list_objects
export -f name_objects
export -f get_objects
export -f list_namespaced_objects
export -f name_namespaced_objects
export -f get_namespaced_objects

list_objects | \
  xargs -r -n1 -P${PARALLELISM_FACTOR} -I {} bash -c 'name_objects "$@"' _ {} | \
  xargs -r -n1 -P${PARALLELISM_FACTOR} -I {} bash -c 'get_objects "$@"' _ {}

get_namespaces | \
  xargs -r -n1 -P${PARALLELISM_FACTOR} -I {} bash -c 'list_namespaced_objects "$@"' _ {} | \
  xargs -r -n1 -P${PARALLELISM_FACTOR} -I {} bash -c 'name_namespaced_objects "$@"' _ {} | \
  xargs -r -n1 -P${PARALLELISM_FACTOR} -I {} bash -c 'get_namespaced_objects "$@"' _ {}
