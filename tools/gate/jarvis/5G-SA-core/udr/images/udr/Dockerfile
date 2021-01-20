ARG FROM=ubuntu:focal
FROM $FROM

SHELL ["bash", "-exc"]
ARG DEBIAN_FRONTEND=noninteractive

# Update distro and install ansible
RUN apt-get update ;\
    apt-get dist-upgrade -y ;\
    apt-get install -y ;\
    apt-get install -y --no-install-recommends \
      software-properties-common ;\
    add-apt-repository ppa:open5gs/latest ;\
    apt-get update ;\
    apt-get install -y --no-install-recommends \
      open5gs-udr ;\
    apt-get clean autoclean ;\
    apt-get autoremove --yes ;\
    rm -rf /var/lib/{apt,dpkg,cache,log}/

ENTRYPOINT ["/usr/bin/open5gs-udrd"]
CMD ["-c", "/etc/open5gs/udr.yaml"]
