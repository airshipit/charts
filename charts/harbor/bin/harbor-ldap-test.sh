#!/bin/sh

set -xe

test_status() {
  curl --head --show-error --silent --fail --location --insecure --request GET \
  --netrc-file $1 \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  ${HARBOR_API_URL}/api/v2.0/statistics | head -n 1 | awk '{print $2}'
}

if [ "$(test_status /etc/harbor/good_ldap.rc)" -ne "200" ]; then
  echo "expected 200"
  exit 1
fi

if [ "$(test_status /etc/harbor/bad_ldap.rc)" -ne "401" ]; then
  echo "expected 401"
  exit 1
fi
