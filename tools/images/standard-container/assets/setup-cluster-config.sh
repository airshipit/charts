#!/bin/bash

cp "$(workspaces.k8s_cluster_data.path)/default.json" "$(workspaces.development_pipeline_data.path)/default.json"
cp "$(workspaces.k8s_cluster_data.path)/cluster.json" "$(workspaces.development_pipeline_data.path)/cluster.json"
jq '.cluster_kubeconfig_path="$(workspaces.development_pipeline_data.path)/config"' "$(workspaces.development_pipeline_data.path)/cluster.json" > "$(workspaces.development_pipeline_data.path)/temp_cluster.json" && mv "$(workspaces.development_pipeline_data.path)/temp_cluster.json" "$(workspaces.development_pipeline_data.path)/cluster.json"
