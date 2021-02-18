#!/bin/bash

set -ex

cp "/workspace/k8s_cluster_data/default.json" "/workspace/development_pipeline_data/default.json"
cp "/workspace/k8s_cluster_data/cluster.json" "/workspace/development_pipeline_data/cluster.json"
jq '.cluster_kubeconfig_path="/workspace/development_pipeline_data/config"' "/workspace/development_pipeline_data/cluster.json" > "/workspace/development_pipeline_data/temp_cluster.json" && mv "/workspace/development_pipeline_data/temp_cluster.json" "/workspace/development_pipeline_data/cluster.json"