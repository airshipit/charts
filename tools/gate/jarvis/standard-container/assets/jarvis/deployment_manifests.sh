#!/bin/bash

set -ex

ansible-playbook -vvv "/playbooks/deployment-manifests.yaml" -i hosts \
 -e @"/workspace/development_pipeline_data/default.json"
