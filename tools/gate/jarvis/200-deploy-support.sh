#!/bin/bash
set -ex

helm repo add jetstack https://charts.jetstack.io
helm upgrade \
    --create-namespace \
    --install \
    --namespace=cert-manager \
    cert-manager \
    jetstack/cert-manager \
    --version v1.2.0 \
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
apiVersion: cert-manager.io/v1
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

cat > /tmp/base.ldif <<EOF
dn: ou=Users,dc=jarvis,dc=local
changetype: add
objectClass: organizationalUnit
ou: Users

dn: ou=Groups,dc=jarvis,dc=local
changetype: add
objectClass: organizationalUnit
ou: Groups

dn: uid=jarvis,ou=Users,dc=jarvis,dc=local
changetype: add
objectClass: top
objectClass: person
objectClass: inetOrgPerson
cn: jarvis
sn: User
displayname: jarvis User
mail: jarvis@cluster.local
userpassword: {SSHA}fCJ5vuW1BQ4/OfOVkkx1qjwi7yHFuGNB

dn: cn=jarvis-admins,ou=Groups,dc=jarvis,dc=local
changetype: add
objectClass: top
objectClass: groupOfUniqueNames
cn: jarvis-admins
description: Jarvis Administrators
uniqueMember: uid=jarvis,ou=Users,dc=jarvis,dc=local
EOF

ldif_add_user() {
local USER=$1
local PASSWORD=$2
cat >> /tmp/base.ldif << EOF

dn: uid=$USER,ou=Users,dc=jarvis,dc=local
changetype: add
objectClass: top
objectClass: person
objectClass: inetOrgPerson
cn: $USER
sn: User
displayname: $USER User
mail: $USER@cluster.local
userpassword: $PASSWORD
EOF
}

project_path=./tools/gate/jarvis/5G-SA-core
if [ -d "$project_path" ]; then
  projects=$(find $project_path  -maxdepth 1 -mindepth 1 -type d -printf '%f\n')
  for proj in $projects; do
    # password: "harbor-user-password"
    ldif_add_user $proj-harbor "{SSHA}u1BT4/+0D4CRCZEFYQHRieswErdUc5Zm"
    # password: "harbor-staging-user-password"
    ldif_add_user $proj-harbor-staging "{SSHA}gYtZk9+9j59ytEj9z6/KUsKw4/CvpaEU"
    # password: "dev-password"
    ldif_add_user $proj-dev "{SSHA}o8PQMzyBjq7+3wlnyFmjWILphtfnZ5tA"
  done
fi

export LDIFFILE=$(cat /tmp/base.ldif)
yq -i eval '.customLdifFiles."groups.ldif" = strenv(LDIFFILE)' charts/ldap/values_overrides/default.yaml

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
