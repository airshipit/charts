#!/bin/bash

set -ex

update-ca-certificates
ansible-playbook -vvv /playbooks/charts-microflow.yaml -i hosts \
 -e '{"stage":"publish"}' \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e 'loop_source="/workspace/development_pipeline_data/chart.json"'
