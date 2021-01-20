#!/bin/sh

set -xe

curl --show-error --fail --location --insecure --request PUT \
  --netrc-file /etc/harbor/admin.rc \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  -d "@/config/config.json" \
  ${HARBOR_API_URL}
