#!/bin/bash

set -ex

: ${HELM_VERSION:="v3.4.1"}
: ${KUBE_VERSION:="v1.19.2"}
: ${MINIKUBE_VERSION:="v1.15.1"}
: ${CALICO_VERSION:="v3.12"}

: "${HTTP_PROXY:=""}"
: "${HTTPS_PROXY:=""}"
: "${NO_PROXY:=""}"

export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBIAN_FRONTEND=noninteractive

# Note: Including fix from https://review.opendev.org/c/openstack/openstack-helm-infra/+/763619/
echo "DefaultLimitMEMLOCK=16384" | sudo tee -a /etc/systemd/system.conf
sudo systemctl daemon-reexec

function configure_resolvconf {
  # Setup resolv.conf to use the k8s api server, which is required for the
  # kubelet to resolve cluster services.
  sudo mv /etc/resolv.conf /etc/resolv.conf.backup

  # Create symbolic link to the resolv.conf file managed by systemd-resolved, as
  # the kubelet.resolv-conf extra-config flag is automatically executed by the
  # minikube start command, regardless of being passed in here
  sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

  sudo bash -c "echo 'nameserver 10.96.0.10' >> /etc/resolv.conf"

  # NOTE(drewwalters96): Use the Google DNS servers to prevent local addresses in
  # the resolv.conf file unless using a proxy, then use the existing DNS servers,
  # as custom DNS nameservers are commonly required when using a proxy server.
  if [ -z "${HTTP_PROXY}" ]; then
    sudo bash -c "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
    sudo bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
  else
    sed -ne "s/nameserver //p" /etc/resolv.conf.backup | while read -r ns; do
      sudo bash -c "echo 'nameserver ${ns}' >> /etc/resolv.conf"
    done
  fi

  sudo bash -c "echo 'search svc.cluster.local cluster.local' >> /etc/resolv.conf"
  sudo bash -c "echo 'options ndots:5 timeout:1 attempts:1' >> /etc/resolv.conf"

  sudo rm /etc/resolv.conf.backup
}

# NOTE: Clean Up hosts file
sudo sed -i '/^127.0.0.1/c\127.0.0.1 localhost localhost.localdomain localhost4localhost4.localdomain4' /etc/hosts
sudo sed -i '/^::1/c\::1 localhost6 localhost6.localdomain6' /etc/hosts

# Install required packages for K8s on host
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
RELEASE_NAME=$(grep 'CODENAME' /etc/lsb-release | awk -F= '{print $2}')
sudo add-apt-repository "deb https://download.ceph.com/debian-nautilus/ ${RELEASE_NAME} main"

. /etc/os-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

sudo -E apt-get update
sudo -E apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  socat \
  jq \
  util-linux \
  nfs-common \
  bridge-utils \
  iptables \
  conntrack \
  libffi-dev \
  ipvsadm

configure_resolvconf

# Prepare tmpfs for etcd
sudo mkdir -p /data
sudo mount -t tmpfs -o size=512m tmpfs /data

# Install minikube and kubectl
URL="https://storage.googleapis.com"
sudo -E curl -sSLo /usr/local/bin/minikube "${URL}"/minikube/releases/"${MINIKUBE_VERSION}"/minikube-linux-amd64
sudo -E curl -sSLo /usr/local/bin/kubectl "${URL}"/kubernetes-release/release/"${KUBE_VERSION}"/bin/linux/amd64/kubectl

sudo -E chmod +x /usr/local/bin/minikube
sudo -E chmod +x /usr/local/bin/kubectl

# Install Helm
TMP_DIR=$(mktemp -d)
sudo -E bash -c \
  "curl -sSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C ${TMP_DIR}"

sudo -E mv "${TMP_DIR}"/helm /usr/local/bin/helm
rm -rf "${TMP_DIR}"

# NOTE: Deploy kubenetes using minikube. A CNI that supports network policy is
# required for validation; use calico for simplicity.
sudo -E minikube config set kubernetes-version "${KUBE_VERSION}"
sudo -E minikube config set vm-driver none
sudo -E minikube config set embed-certs true

export CHANGE_MINIKUBE_NONE_USER=true
export MINIKUBE_IN_STYLE=false
sudo -E minikube start \
  --docker-env HTTP_PROXY="${HTTP_PROXY}" \
  --docker-env HTTPS_PROXY="${HTTPS_PROXY}" \
  --docker-env NO_PROXY="${NO_PROXY},10.96.0.0/12" \
  --network-plugin=cni \
  --extra-config=controller-manager.allocate-node-cidrs=true \
  --extra-config=controller-manager.cluster-cidr=192.168.0.0/16 \
  --extra-config=kube-proxy.mode=ipvs

minikube addons list

curl https://docs.projectcalico.org/"${CALICO_VERSION}"/manifests/calico.yaml -o /tmp/calico.yaml
kubectl apply -f /tmp/calico.yaml

# Note: Patch calico daemonset to enable Prometheus metrics and annotations
tee /tmp/calico-node.yaml << EOF
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9091"
    spec:
      containers:
        - name: calico-node
          env:
            - name: FELIX_PROMETHEUSMETRICSENABLED
              value: "true"
            - name: FELIX_PROMETHEUSMETRICSPORT
              value: "9091"
EOF
kubectl -n kube-system patch daemonset calico-node --patch "$(cat /tmp/calico-node.yaml)"
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

kubectl get pod -A
kubectl -n kube-system get pod -l k8s-app=kube-dns

# NOTE: Wait for dns to be running.
END=$(($(date +%s) + 240))
until kubectl --namespace=kube-system \
        get pods -l k8s-app=kube-dns --no-headers -o name | grep -q "^pod/coredns"; do
  NOW=$(date +%s)
  [ "${NOW}" -gt "${END}" ] && exit 1
  echo "still waiting for dns"
  sleep 10
done
kubectl -n kube-system wait --timeout=240s --for=condition=Ready pods -l k8s-app=kube-dns

# Remove stable repo, if present, to improve build time
helm repo remove stable || true

# Add labels to the core namespaces
kubectl label --overwrite namespace default name=default
kubectl label --overwrite namespace kube-system name=kube-system
kubectl label --overwrite namespace kube-public name=kube-public
