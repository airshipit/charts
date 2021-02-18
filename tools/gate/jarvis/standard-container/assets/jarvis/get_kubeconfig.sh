#!/bin/bash

set -ex
ls -ltr /workspace/development_pipeline_data
pwd
ansible-playbook -vvv "/playbooks/get-kubeconfig.yaml"  -i hosts \
 -e @"/workspace/development_pipeline_data/default.json" \
 -e @"/workspace/development_pipeline_data/cluster.json"