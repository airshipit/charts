#!/bin/bash
set -ex

for cfssl_bin in cfssl cfssljson; do
  if ! type -p "${cfssl_bin}"; then
    version=$(curl --silent "https://api.github.com/repos/cloudflare/cfssl/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    version_number=${version#"v"}
    sudo -E curl -L -o "/usr/local/bin/${cfssl_bin}" "https://github.com/cloudflare/cfssl/releases/download/${version}/${cfssl_bin}_${version_number}_linux_amd64"
    sudo -E chmod +x "/usr/local/bin/${cfssl_bin}"
    ls "/usr/local/bin/${cfssl_bin}"
  fi
done

jarvis_config_root="/etc/jarvis"
jarvis_ca_root="${jarvis_config_root}/certs/ca"

sudo mkdir -p "${jarvis_config_root}"
sudo chown "$(whoami):" -R "${jarvis_config_root}"

mkdir -p "${jarvis_ca_root}"
tee "${jarvis_ca_root}/ca-config.json" << EOF
{
    "signing": {
        "default": {
            "expiry": "1y"
        },
        "profiles": {
            "server": {
                "expiry": "1y",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            }
        }
    }
}
EOF

tee ${jarvis_ca_root}/ca-csr.json << EOF
{
  "CN": "Jarvis CI/CD",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Insecure",
      "ST": "Local",
      "O": "Development",
      "OU": "Ephemeral"
    }
  ]
}
EOF

cfssl gencert -initca ${jarvis_ca_root}/ca-csr.json | cfssljson -bare ${jarvis_ca_root}/ca -

function check_cert_and_key () {
    local tls_cert_path
    tls_cert_path="${1}"
    local tls_key_path
    tls_key_path="${2}"
    openssl x509 -inform pem -in "${tls_cert_path}" -noout -text
    local cert_modulus
    cert_modulus="$(openssl x509 -noout -modulus -in "${tls_cert_path}")"
    local key_modulus
    key_modulus="$(openssl rsa -noout -modulus -in "${tls_key_path}")"
    if ! [ "${cert_modulus}" = "${key_modulus}" ]; then
        echo "Failure: TLS private key does not match this certificate."
        exit 1
    else
        echo "Pass: ${tls_cert_path} is valid with ${tls_key_path}"
    fi
}
check_cert_and_key ${jarvis_ca_root}/ca.pem ${jarvis_ca_root}/ca-key.pem

sudo cp -v ${jarvis_ca_root}/ca.pem /usr/local/share/ca-certificates/insecure-jarvis-development-ephemeral-ca.crt
sudo update-ca-certificates
