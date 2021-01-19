#!/bin/bash
set -ex

helm repo add jetstack https://charts.jetstack.io
helm upgrade \
    --create-namespace \
    --install \
    --namespace=cert-manager \
    cert-manager \
    jetstack/cert-manager \
    --version v1.1.0 \
    --set installCRDs=true

./tools/deployment/common/wait-for-pods.sh cert-manager

key=$(base64 -w0 /etc/jarvis/certs/ca/ca-key.pem)
crt=$(base64 -w0 /etc/jarvis/certs/ca/ca.pem)
tee /tmp/ca-issuers.yaml <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: jarvis-ca-key-pair
  namespace: cert-manager
data:
  tls.crt: $crt
  tls.key: $key
---
apiVersion: cert-manager.io/v1alpha3
kind: ClusterIssuer
metadata:
  name: jarvis-ca-issuer
spec:
  ca:
    secretName: jarvis-ca-key-pair
EOF
kubectl apply -f /tmp/ca-issuers.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade \
    --create-namespace \
    --install \
    --namespace=ingress-nginx \
    ingress-nginx \
    ingress-nginx/ingress-nginx \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=80 \
    --set controller.service.nodePorts.https=443

./tools/deployment/common/wait-for-pods.sh ingress-nginx

helm repo add stable https://charts.helm.sh/stable
# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=ldap \
    ldap \
    stable/openldap \
    $(./tools/deployment/common/get-values-overrides.sh ldap)

./tools/deployment/common/wait-for-pods.sh ldap
