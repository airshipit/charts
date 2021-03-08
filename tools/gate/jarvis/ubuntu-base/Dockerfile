ARG BASE_IMAGE=ubuntu:focal
FROM ${BASE_IMAGE}

ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

COPY ./internal-certs /usr/local/share/ca-certificates

RUN apt-get update \
 && apt-get install \
      --no-install-recommends \
      --yes \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV http_proxy $http_proxy
ENV https_proxy $https_proxy
ENV no_proxy $no_proxy
ENV HTTP_PROXY $HTTP_PROXY
ENV HTTPS_PROXY $HTTPS_PROXY
ENV NO_PROXY $NO_PROXY
