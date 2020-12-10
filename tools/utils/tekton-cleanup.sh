#!/bin/bash

set -ex

: ${TEKTON_NS:="tekton-pipelines"}

tekton_releases=$(helm -n $TEKTON_NS ls -q)
if [ -z "$tekton_releases" ]; then
  echo "no release in $TEKTON_NS found"
else
  for release in $tekton_releases; do
    helm -n $TEKTON_NS uninstall $release
  done

  # waits til the resources are cleaned up
  sleep 30

  # helm uninstalls should clean up all the resources, but in the scenarios they are orphaned,
  # this should attempt to clean it up.
  for resource in mutatingwebhookconfigurations validatingwebhookconfigurations; do
    kubectl -n $TEKTON_NS get $resource -o name | awk -F'/' '{print $2}' | grep tekton.dev | xargs -r kubectl -n $TEKTON_NS delete $resource
  done
fi
