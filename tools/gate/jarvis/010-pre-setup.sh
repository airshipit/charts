#!/bin/bash
set -ex

# NOTE: Use this script to perform necessary actions prior to start of the main
# deployment.

# Add the necessary corporate nameserver to systemd-resolved so it
# propagates properly and prevent it from overwriting.
# Replace 123.123.123.4 with the correct IP
: "${PRIVATE_NS:=""}"
if [ -n "${PRIVATE_NS}" ]; then
  sudo -E sed -i -e 's/^DNS=/#DNS=/' /etc/systemd/resolved.conf
  sudo -E sed -i -e "/^\[Resolve\]$/a DNS=${PRIVATE_NS}" /etc/systemd/resolved.conf
  sudo rm -f /etc/resolv.conf
  sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
  sudo systemctl restart systemd-resolved
fi

# Update CA certificates in case internal certs have been mounted to /usr/share/local/ca-certificates
# via Vagrantfile. Need to run update-ca-certificates before any `curl`, etc. commands are done.
sudo update-ca-certificates
