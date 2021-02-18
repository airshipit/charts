#!/bin/bash

set -ex

ansible-playbook -vvv /playbooks/charts-microflow.yaml -i hosts \
 -e '{"stage":"package"}' \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e 'loop_source="/workspace/development_pipeline_data/chart.json"'
