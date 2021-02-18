#!/bin/bash

set -ex
update-ca-certificates
ansible-playbook -vvv /playbooks/promote-microflow.yaml -i hosts \
 -e '{"stage":"promote_image"}' \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e 'loop_source="/workspace/development_pipeline_data/image.json"'

ansible-playbook -vvv /playbooks/promote-microflow.yaml -i hosts \
 -e '{"stage":"promote_chart"}' \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e 'loop_source="/workspace/development_pipeline_data/chart.json"'
