#!/bin/bash

set -ex

update-ca-certificates
ansible-playbook -vvv /playbooks/functional-microflow.yaml -i hosts \
  -e '{"stage":"deploy"}' \
  -e @"/workspace/development_pipeline_data/default.json" \
  -e @"/workspace/development_pipeline_data/cluster.json" \
  -e 'loop_source="/workspace/development_pipeline_data/chart.json"' \
  -e '{"datapath":"/workspace/development_pipeline_data"}'
