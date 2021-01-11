BUILD_DIR         := $(shell mktemp -d)
IMAGE_BASE        ?= ubuntu:20.04
IMAGE_PREFIX      ?= test
IMAGE_REGISTRY    ?= core.harbor.domain
IMAGE_TAG         ?= 1.0
IMAGE_NAME        ?= standard-container
PROXY             ?= http://proxy.foo.com:8000
NO_PROXY          ?= localhost,127.0.0.1,.svc.cluster.local
USE_PROXY         ?= false
# use this variable for image labels added in internal build process
LABEL             ?= org.attcomdev.build=community
COMMIT            ?= $(shell git rev-parse HEAD)
DISTRO            ?= ubuntu_bionic
IMAGE_FULLNAME    := ${IMAGE_REGISTRY}/${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}

.PHONY: help

SHELL:=/bin/bash
.ONESHELL:

help: ## This help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

build: ## Build the containers.
	docker build --tag $(IMAGE_FULLNAME) --build-arg BASE_IMAGE=$(IMAGE_BASE) ./$(IMAGE_NAME)

push: build ## Build and push the containers
	docker push $(IMAGE_FULLNAME)
