#!/bin/bash
set -ex

: "${HELM_VERSION:="v3.4.2"}"
: "${KUBE_VERSION:="v1.19.6"}"
: "${MINIKUBE_VERSION:="v1.16.0"}"
: "${CALICO_VERSION:="v3.17"}"

: "${HTTP_PROXY:=""}"
: "${HTTPS_PROXY:=""}"
: "${NO_PROXY:=""}"

: "${LOOPBACK_DOMAIN_TO_HOST:="jarvis.local"}"

export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBIAN_FRONTEND=noninteractive

sudo swapoff -a

# Note: Including fix from https://review.opendev.org/c/openstack/openstack-helm-infra/+/763619/
echo "DefaultLimitMEMLOCK=16384" | sudo tee -a /etc/systemd/system.conf
sudo systemctl daemon-reexec

# Function to help generate a resolv.conf formatted file.
# Arguments are positional:
#    1st is location of file to be generated
#    2nd is a custom nameserver that should be used exclusively if avalible.
function generate_resolvconf() {
  local target
  target="${1}"
  local priority_nameserver
  priority_nameserver="${2}"
  if [[ ${priority_nameserver} ]]; then
  sudo -E tee "${target}" <<EOF
nameserver ${priority_nameserver}
EOF
  fi
  local nameservers_systemd
  nameservers_systemd="$(awk '/^nameserver/ { print $2 }' /run/systemd/resolve/resolv.conf | sed '/^127.0.0./d')"
  if [[ ${nameservers_systemd} ]]; then
    for nameserver in ${nameservers_systemd}; do
      sudo -E tee --append "${target}" <<EOF
nameserver ${nameserver}
EOF
    done
  else
    sudo -E tee --append "${target}" <<EOF
nameserver 1.0.0.1
nameserver 8.8.8.8
EOF
  fi
  if [[ ${priority_nameserver} ]]; then
  sudo -E tee --append "${target}" <<EOF
options timeout:1 attempts:1
EOF
  fi
}

# NOTE: Clean Up hosts file
sudo sed -i '/^127.0.0.1/c\127.0.0.1 localhost localhost.localdomain localhost4localhost4.localdomain4' /etc/hosts
sudo sed -i '/^::1/c\::1 localhost6 localhost6.localdomain6' /etc/hosts

# shellcheck disable=SC1091
. /etc/os-release

# NOTE: Add docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

# NOTE: Configure docker
docker_resolv="$(mktemp -d)/resolv.conf"
generate_resolvconf "${docker_resolv}"
docker_dns_list="$(awk '/^nameserver/ { printf "%s%s",sep,"\"" $NF "\""; sep=", "} END{print ""}' "${docker_resolv}")"

sudo -E mkdir -p /etc/docker
sudo -E tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "dns": [${docker_dns_list}]
}
EOF

if [ -n "${HTTP_PROXY}" ]; then
  sudo mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF | sudo -E tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
Environment="HTTPS_PROXY=${HTTPS_PROXY}"
Environment="NO_PROXY=${NO_PROXY}"
EOF
fi

sudo -E apt-get update
sudo -E apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  socat \
  jq \
  util-linux \
  bridge-utils \
  iptables \
  conntrack \
  libffi-dev \
  ipvsadm \
  make \
  bc \
  git-review

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

# NOTE: Setup nameservers for the kubelet to use. Configuring dnsmasq to direct all requests for a
# domain back to the interface on the default route if required. This is useful for testing ingress
# controllers, and/or other services which would normally be reached over an externally manged DNS
# service (eg Gerrit SSH).
sudo -E mkdir -p /etc/kubernetes
if [[ ${LOOPBACK_DOMAIN_TO_HOST} ]]; then
  default_gateway_device="$(ip -4 route list 0/0 | awk -F 'dev' '{ print $2; exit }' | awk '{ print $1 }')"
  host_ip="$(ip -4 addr show "${default_gateway_device}" | awk '/inet/ { print $2; exit }' | awk -F "/" '{ print $1 }')"
  # shellcheck disable=SC2140
  sudo -E docker network create \
    --driver=bridge \
    --subnet=172.28.0.0/30 \
    -o "com.docker.network.bridge.name"="docker1" \
    dns
  sudo -E docker run -d \
    --name dns-loopback \
    --restart always \
    --network=dns \
    quay.io/airshipit/dnsmasq:latest-ubuntu_bionic \
      dnsmasq \
      --no-daemon \
      --no-hosts \
      --bind-interfaces \
      --address="/${LOOPBACK_DOMAIN_TO_HOST}/${host_ip}"
  sudo tee /etc/kubernetes/kubelet_resolv.conf <<EOF
nameserver 172.28.0.2
EOF
  sudo rm -f /etc/resolv.conf
  generate_resolvconf /etc/resolv.conf 172.28.0.2
else
  generate_resolvconf /etc/kubernetes/kubelet_resolv.conf
fi

# NOTE: Deploy kubernetes using minikube. A CNI that supports network policy is
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
  --extra-config=kube-proxy.mode=ipvs \
  --extra-config=apiserver.service-node-port-range=1-65535 \
  --extra-config=kubelet.resolv-conf=/etc/kubernetes/kubelet_resolv.conf \
  --extra-config=kubelet.cgroup-driver=systemd
sudo -E systemctl enable --now kubelet

minikube addons list

curl https://docs.projectcalico.org/"${CALICO_VERSION}"/manifests/calico.yaml -o /tmp/calico.yaml
# NOTE: Changes the default repository to use quay.io. Running this script multiple times can result
# in image pull error due to dockerhub's rate limiting policy. To avoid potential conflict,
# use calico's quay.io repository to mitigate this issue.
sed -i -e 's#docker.io/calico/#quay.io/calico/#g' /tmp/calico.yaml
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
