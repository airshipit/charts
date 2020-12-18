==================
All-In-One Details
==================

Override-able Variables
=======================

The all-in-one script provides a number of environment variables that users
can alter the behavior.

- ``DEPLOY_K8S``. Default value: ``true``. Setting this value to ``false`` will
  cause the script to not execute the Kubernetes deployment script. User is
  expected to have a Kubernetes cluster running, with ``kubectl`` and ``helm``
  (version 3) available that interact with said cluster.
- **Namespaces**: the Kubernetes and helm namespaces the charts will deploy to.

  - ``TEKTON_NS``. Default value: ``tekton-pipelines``.
  - ``HARBOR_NS``. Default value: ``harbor``.
  - ``LOKI_NS``. Default value: ``loki-stack``.
  - ``GRAFANA_NS``. Default value: ``grafana``.
  - ``NFS_NS``. Default value: ``nfs``.

- ``HARBOR_VERSION``. Default value: ``1.5.2``. The version of the upstream
  goharbor helm chart is pinned to a specific version to avoid unintended
  upgrade conflict.
- ``CHART_ROOT_PATH``. Default value: ``./charts`` This specify the path
  of the charts. If this path is relative, it is relative the root
  of the cloned repository.
- Chart installation override variables. The following are provided:

  - ``EXTRA_HELM_ARGS_NFS``
  - ``EXTRA_HELM_ARGS_HARBOR``
  - ``EXTRA_HELM_ARGS_TEKTON_PIPELINES``
  - ``EXTRA_HELM_ARGS_TEKTON_TRIGGERS``
  - ``EXTRA_HELM_ARGS_TEKTON_DASHBOARD``
  - ``EXTRA_HELM_ARGS_GRAFANA``
  - ``EXTRA_HELM_ARGS_LOKI_STACK``
