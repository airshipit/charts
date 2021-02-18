#!/bin/bash

set -ex

: "${CONTEXT_UID:=$1}"

cp "/workspace/k8s_cluster_data/image.json" "/workspace/development_pipeline_data/image.json"
jq 'if type=="array" then . else [.] end' "/workspace/development_pipeline_data/image.json" > "/workspace/development_pipeline_data/temp_image.json" && mv "/workspace/development_pipeline_data/temp_image.json" "/workspace/development_pipeline_data/image.json"

echo "Set image_fullname"
jq "reduce range(0, length) as \$d (.; (.[\$d].image_fullname=\"test/scan-image:\"+(\$d|tostring)+\"${CONTEXT_UID}\"))" "/workspace/development_pipeline_data/image.json" > "/workspace/development_pipeline_data/temp_image.json" && mv "/workspace/development_pipeline_data/temp_image.json" "/workspace/development_pipeline_data/image.json"

echo "Set tag to context ${CONTEXT_UID}"
jq "reduce range(0, length) as \$d (.; (.[\$d].tag=\"${CONTEXT_UID}\"))" "/workspace/development_pipeline_data/image.json" > "/workspace/development_pipeline_data/temp_image.json" && mv "/workspace/development_pipeline_data/temp_image.json" "/workspace/development_pipeline_data/image.json"

echo "Set target location for git repository to /workspace/development_pipeline_data/${CONTEXT_UID}"
jq "reduce range(0, length) as \$d (.; (.[\$d].build.target_loc=\"/workspace/development_pipeline_data/${CONTEXT_UID}\"+.[\$d].build.repo+\"/\"+.[\$d].build.refspec))" "/workspace/development_pipeline_data/image.json" > "/workspace/development_pipeline_data/temp_image.json" && mv "/workspace/development_pipeline_data/temp_image.json" "/workspace/development_pipeline_data/image.json"

cat "/workspace/development_pipeline_data/image.json"