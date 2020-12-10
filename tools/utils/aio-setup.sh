#!/bin/bash

set -ex

: ${TEKTON_NS:="tekton-pipelines"}
: ${HARBOR_NS:="harbor"}
: ${LOKI_NS:="loki-stack"}
: ${NFS_NS:="nfs"}
: ${GRAFANA_NS:="grafana"}
: ${CHART_ROOT_PATH:="./charts"}
: ${CLONE_REPO:="false"}
: ${DEPLOY_K8S:="true"}
: ${HARBOR_VERSION:="1.5.2"}

# ensures we have git
sudo -E apt install -y git

# clones upstream rep
if [ $CLONE_REPO == "true" ]; then
  git clone "https://review.opendev.org/airship/charts" airship-charts
  cd airship-charts
fi

# deploys k8s locally on machine, this also deploys calico
if [ $DEPLOY_K8S == "true" ]; then
  ./tools/gate/deploy-k8s.sh
fi

# creates namespaces
kubectl create namespace $NFS_NS || true
kubectl create namespace $HARBOR_NS || true
kubectl create namespace $TEKTON_NS || true
kubectl create namespace $GRAFANA_NS || true
kubectl create namespace $LOKI_NS || true

# adds all the necessary repo here and update
helm repo add osh https://tarballs.opendev.org/openstack/openstack-helm-infra
helm repo add harbor https://helm.goharbor.io
helm repo add loki https://grafana.github.io/loki/charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# adds label here so the OSH chart can be target the node
kubectl label nodes --all openstack-control-plane=enabled --overwrite

# deploys nfs
helm upgrade --install nfs-provisioner osh/nfs-provisioner \
  --namespace=$NFS_NS \
  --set storage.persistentVolumeClaim.size=10Gi \
  --set storage.persistentVolumeClaim.class_name=nfs-provisioner \
  ${EXTRA_HELM_ARGS_NFS}

# waits for the pods to get ready
kubectl wait --for=condition=ready pod --timeout=600s --all -n $NFS_NS

# deploys harbor
tee /tmp/harbor.yaml << EOF
expose:
  tls:
    enabled: false
internalTLS:
  enabled: false
persistence:
  persistentVolumeClaim:
    registry:
      storageClass: nfs-provisioner
    chartmuseum:
      storageClass: nfs-provisioner
    jobservice:
      storageClass: nfs-provisioner
    database:
      storageClass: nfs-provisioner
      size: 5Gi
    redis:
      storageClass: nfs-provisioner
    trivy:
      storageClass: nfs-provisioner
EOF

helm upgrade --install harbor harbor/harbor \
  --namespace=$HARBOR_NS \
  --values=/tmp/harbor.yaml \
  --version=${HARBOR_VERSION} \
  ${EXTRA_HELM_ARGS_HARBOR}

# deploys tekton
tee /tmp/dashboard.yaml << EOF
config:
  args:
    read_only: true
EOF

helm upgrade --install tekton-pipelines ${CHART_ROOT_PATH}/tekton-pipelines \
  --namespace=$TEKTON_NS \
  ${EXTRA_HELM_ARGS_TEKTON_PIPELINES}

helm upgrade --install tekton-triggers ${CHART_ROOT_PATH}/tekton-triggers \
  --namespace=$TEKTON_NS \
  ${EXTRA_HELM_ARGS_TEKTON_TRIGGERS}

helm upgrade --install tekton-dashboard ${CHART_ROOT_PATH}/tekton-dashboard \
  --namespace=$TEKTON_NS \
  --values=/tmp/dashboard.yaml \
  ${EXTRA_HELM_ARGS_TEKTON_DASHBOARD}

# waits for the pods to get ready
kubectl wait --for=condition=ready pod --timeout=600s --all -n $TEKTON_NS
kubectl wait --for=condition=ready pod --timeout=600s --all -n $HARBOR_NS

# installs grafana and loki from upstream chart
helm upgrade --install grafana grafana/grafana \
  --namespace=$GRAFANA_NS \
  ${EXTRA_HELM_ARGS_GRAFANA}

helm upgrade --install loki-stack loki/loki-stack \
  --namespace=$LOKI_NS \
  ${EXTRA_HELM_ARGS_LOKI_STACK}

# waits for the pods to get ready
kubectl wait --for=condition=ready pod --timeout=600s --all -n $GRAFANA_NS
kubectl wait --for=condition=ready pod --timeout=600s --all -n $LOKI_NS
