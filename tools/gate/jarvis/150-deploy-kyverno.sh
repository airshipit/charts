#!/bin/bash
set -ex

# Add the Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/

# Scan your Helm repositories to fetch the latest available charts.
helm repo update

# Install the Kyverno Helm chart into a new namespace called "kyverno"
helm upgrade \
    --install \
    --namespace kyverno \
    kyverno \
    kyverno/kyverno \
    --version v1.3.3 \
    --create-namespace

./tools/deployment/common/wait-for-pods.sh kyverno
