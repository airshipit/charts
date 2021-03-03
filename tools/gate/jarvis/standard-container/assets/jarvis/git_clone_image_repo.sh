#!/bin/bash

set -ex

update-ca-certificates

ansible-playbook -vvv /playbooks/git-microflow.yaml -i hosts \
 -e '{"stage":"clone"}' \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e 'loop_source="/workspace/development_pipeline_data/image.json"'