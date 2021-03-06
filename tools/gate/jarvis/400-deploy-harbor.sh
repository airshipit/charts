#!/bin/bash
set -ex

make -C ./charts harbor

# shellcheck disable=SC2046
helm upgrade \
    --create-namespace \
    --install \
    --namespace=harbor \
    --set harbor.proxy.httpProxy="$http_proxy" \
    --set harbor.proxy.httpsProxy="$https_proxy" \
    harbor \
    ./charts/harbor \
    $(./tools/deployment/common/get-values-overrides.sh harbor)

./tools/deployment/common/wait-for-pods.sh harbor

# Setup internal certs so that Trivy can download its database.
# Harbor's Trivy statefulset image is based on PhotonOS, which doesn't have
# an update-ca-certificates package.
# PhotonOS has support to generate the ca-bundle, but it's not installed in this
# image. The statefulset also prevents privilege escalation, so we can't intervene and
# install that.
# So, hackily append .crt files to the ca-bundle.crt.
for cert in ./tools/gate/jarvis/ubuntu-base/internal-certs/*.crt; do
    kubectl exec harbor-harbor-trivy-0 \
        --namespace harbor \
        -- /bin/bash -c "echo \"$(cat $cert)\" >> /etc/pki/tls/certs/ca-bundle.crt"
done

helm -n harbor test harbor --logs

function validate() {
    helm plugin update push || helm plugin install https://github.com/chartmuseum/helm-push

    # Downloads a chartmuseum tarball and upload it to a newly created repo in harbor
    helm repo add stable https://charts.helm.sh/stable
    local source_chart_dir
    source_chart_dir="$(mktemp -d)"
    helm pull stable/chartmuseum --destination "${source_chart_dir}"
    helm repo add jarvis-harbor "https://harbor-core.jarvis.local/chartrepo" --username=admin --password=Harbor12345
    helm push --username=admin --password=Harbor12345 "$(ls "${source_chart_dir}"/chartmuseum*.tgz)" jarvis-harbor
    helm repo update
    local chart_dir
    chart_dir="$(mktemp -d)"
    helm pull jarvis-harbor/library/chartmuseum --destination "${chart_dir}"
    # Tests that we can upload an image
    sudo -E docker pull quay.io/crio/busybox:latest
    sudo -E docker login harbor-core.jarvis.local --username admin --password Harbor12345
    sudo -E docker tag quay.io/crio/busybox:latest harbor-core.jarvis.local/library/busybox:latest

    # Perform a trust inspect on the image that was pulled down. This returns a $? of 1,
    # as there is no trust signature attached.
    set +e
    sudo -E docker trust inspect --pretty harbor-core.jarvis.local/library/busybox:latest
    set -e

    sudo mkdir -p ~/.notary
    sudo -E tee ~/.notary/config.json <<EOF
{
  "trust_dir" : "~/.docker/trust",
  "remote_server": {
    "url": "https://harbor-notary.jarvis.local",
    "root_ca": "/etc/jarvis/certs/ca/ca.pem"
  }
}
EOF

    export NOTARY_ROOT_PASSPHRASE=passphrase
    export NOTARY_TARGETS_PASSPHRASE=passphrase
    export NOTARY_SNAPSHOT_PASSPHRASE=passphrase
    export NOTARY_DELEGATION_PASSPHRASE=passphrase

    LDAPUSERNAME=$(grep ldap_username ./charts/harbor/values.yaml | awk '{print $2}')
    LDAPPASSWORD=$(grep ldap_password ./charts/harbor/values.yaml | awk '{print $2}')
    export NOTARY_AUTH=$(echo "$LDAPUSERNAME:$LDAPPASSWORD" | base64)

    export DOCKER_CONTENT_TRUST=1
    export DOCKER_CONTENT_TRUST_SERVER=https://harbor-notary.jarvis.local:443
    export DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=passphrase
    export DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=passphrase

    sudo -E notary init -p harbor-core.jarvis.local/library/busybox
    sudo -E docker push harbor-core.jarvis.local/library/busybox:latest

    # Test that we can download an image
    sudo -E docker rmi harbor-core.jarvis.local/library/busybox:latest
    sudo -E docker pull harbor-core.jarvis.local/library/busybox:latest
    sudo -E docker trust inspect --pretty harbor-core.jarvis.local/library/busybox:latest

    #Required for pipelines and standard-container
    pushd ./tools/gate/jarvis/ubuntu-base/
    sudo docker build --build-arg http_proxy="$http_proxy" --build-arg https_proxy="$https_proxy" --build-arg no_proxy="$no_proxy" --build-arg HTTP_PROXY="$http_proxy" --build-arg HTTPS_PROXY="$https_proxy" --build-arg NO_PROXY="$no_proxy" -t harbor-core.jarvis.local/library/ubuntu:focal .
    popd
    sudo -E notary init -p harbor-core.jarvis.local/library/ubuntu:focal
    sudo -E docker push harbor-core.jarvis.local/library/ubuntu:focal
}

validate
