ARG BASE_IMAGE=harbor-core.jarvis.local/library/ubuntu:focal
FROM ${BASE_IMAGE}

SHELL ["bash", "-exc"]
ENV DEBIAN_FRONTEND noninteractive

# Update distro and install ansible
RUN apt-get update ;\
    apt-get dist-upgrade -y ;\
    apt-get install -y \
        python3-minimal \
        python3-pip \
        python3-setuptools \
        make \
        sudo \
        git \
        jq \
        curl \
        git-review \
        apt-transport-https \
        ca-certificates \
        gnupg-agent \
        software-properties-common \
        gettext-base ;\
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - ;\
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" ;\
    apt-get install -y --no-install-recommends \
        docker-ce-cli ;\
    pip3 install --upgrade wheel ;\
    pip3 install ansible==2.10.7 ;\
    pip3 install yq ;\
    ansible-galaxy collection install community.kubernetes ;\
    pip3 install docker ;\
    # Install kubectl
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        gnupg2 ;\
    curl -o /usr/bin/kubectl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" ;\
    chmod +x /usr/bin/kubectl ;\
    # Install Helm
    curl -fsSL -o helm-install.tar.gz https://get.helm.sh/helm-v3.4.2-linux-amd64.tar.gz \
    && tar -xvf helm-install.tar.gz \
    && rm helm-install.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && helm --help ;\
    helm plugin install https://github.com/chartmuseum/helm-push ;\
    rm -rf /var/lib/apt/lists/*

COPY assets /opt/assets/
RUN cp -ravf /opt/assets/* / ;\
    rm -rf /opt/assets

ENTRYPOINT /git_clone.sh
