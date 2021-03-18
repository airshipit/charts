#!/bin/bash

set -ex

ansible-playbook -vvv "/playbooks/cleanup.yaml" -i hosts \
  -e @"/workspace/development_pipeline_data/default.json" \
  -e 'loop_chart_source="/workspace/development_pipeline_data/chart.json"' \
  -e 'loop_image_source="/workspace/development_pipeline_data/image.json"' \
  -e @"/workspace/development_pipeline_data/cleanup.json" \
  -e @"/workspace/development_pipeline_data/cluster.json"