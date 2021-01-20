#!/bin/sh

set -xe

test_status() {
  curl --head --show-error --silent --fail --location --insecure --request GET \
    --netrc-file $1 \
    -H "accept: application/json" \
    -H "content-type: application/json" \
    ${GRAFANA_URI}/api/org | head -n 1 | awk '{print $2}'
}

if [ "$(test_status /etc/loki/good_ldap.rc)" -ne "200" ]; then
  echo "expected 200"
  exit 1
fi

if [ "$(test_status /etc/loki/bad_ldap.rc)" -ne "401" ]; then
  echo "expected 401"
  exit 1
fi
