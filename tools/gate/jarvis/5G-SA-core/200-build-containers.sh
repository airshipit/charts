#!/bin/bash
set -ex

: "${image_registry:="quay.io"}"
: "${image_repo:="port"}"
: "${image_prefix:="open5gs"}"
: "${image_tag:="latest"}"

: "${push_images:="false"}"

for dockerfile_path in `find ./tools/gate/jarvis/5G-SA-core -name Dockerfile`; do
  build_root=`dirname ${dockerfile_path}`
  network_function=`echo $build_root | awk -F '/' '{ print $NF }'`
  image_uri="${image_registry}/${image_repo}/${image_prefix}-${network_function}:${image_tag}"
  sudo docker build -t "${image_uri}" "${build_root}"
  if [[ "${push_images}" == "true" ]]; then
    docker push "${image_uri}"
  fi
done
