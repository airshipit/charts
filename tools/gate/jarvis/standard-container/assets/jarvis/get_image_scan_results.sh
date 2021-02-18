#!/bin/bash

set -ex

ansible-playbook -vvv /playbooks/images-microflow.yaml -i hosts \
 -e '{"stage":"scan_results"}' \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e 'loop_source="/workspace/development_pipeline_data/image.json"'