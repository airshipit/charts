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
  --namespace=${TEKTON_NS} \
  ${EXTRA_HELM_ARGS_TEKTON_PIPELINES}

helm upgrade --install tekton-triggers ${CHART_ROOT_PATH}/tekton-triggers \
  --namespace=${TEKTON_NS} \
  ${EXTRA_HELM_ARGS_TEKTON_TRIGGERS}

helm upgrade --install tekton-dashboard ${CHART_ROOT_PATH}/tekton-dashboard \
  --namespace=${TEKTON_NS} \
  --values=/tmp/dashboard.yaml \
  ${EXTRA_HELM_ARGS_TEKTON_DASHBOARD}

# waits for the pods to get ready
kubectl wait --for=condition=ready pod --timeout=600s --all -n ${TEKTON_NS}
kubectl wait --for=condition=ready pod --timeout=600s --all -n ${HARBOR_NS}

tee /tmp/loki.yaml << EOF
loki:
  enabled: true
  ingress:
    enabled: true
    hosts:
      - host: loki.jarvis.local
        paths: ["/"]
    public: true
    annotations:
      nginx.ingress.kubernetes.io/configuration-snippet: |
        more_set_headers "X-Frame-Options: deny";
        more_set_headers "X-XSS-Protection: 1; mode=block";
      nginx.ingress.kubernetes.io/rewrite-target: /
promtail:
  enabled: true
grafana:
  enabled: false
EOF

tee /tmp/grafana.yaml << EOF
ingress:
  enabled: true
  hosts: ["grafana","grafana.jarvis","grafana.jarvis.svc.cluster.local"]
  public: true
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: deny";
      more_set_headers "X-XSS-Protection: 1; mode=block";
    nginx.ingress.kubernetes.io/rewrite-target: /
  labels: {}
  path: /
  hosts:
    - grafana-jarvis.domain
  ## Extra paths to prepend to every host configuration. This is useful when working with annotation based services.
  extraPaths: []
  tls: []
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
persistence:
  type: pvc
  enabled: false
  storageClassName: nfs-provisioner
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  # annotations: {}
  finalizers:
    - kubernetes.io/pvc-protection
adminUser: admin
# adminPassword: strongpassword
admin:
  existingSecret: ""
  userKey: admin-user
  passwordKey: admin-password
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki.loki-stack:3100
      version: 1
EOF

# install loki-stack with Loki and Promtail from Grafana helm charts repo
helm upgrade --install loki grafana/loki-stack \
  --namespace=${LOKI_NS} \
  --values=/tmp/loki.yaml \
  ${EXTRA_HELM_ARGS_LOKI_STACK}

kubectl wait --for=condition=ready pod --timeout=600s --namespace ${LOKI_NS} --all

# install Grafana from Grafana helm charts repo
helm upgrade --install grafana grafana/grafana \
  --namespace=${GRAFANA_NS} \
  --values=/tmp/grafana.yaml \
  ${EXTRA_HELM_ARGS_GRAFANA}

kubectl wait --for=condition=ready pod --timeout=600s --namespace ${GRAFANA_NS} --all
