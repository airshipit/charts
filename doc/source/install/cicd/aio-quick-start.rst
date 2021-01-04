======================
All-In-One Quick Start
======================

Initial Setup
=============

It is strongly recommended that the following be performed in a virtual
machine (VM).

Run AIO Setup Script
====================

Clone the `Airship Charts repository <https://opendev.org/airship/charts>`_ by:

.. code:: bash

   git clone https://opendev.org/airship/charts.git airship-charts

Go into the directory and run:

.. code:: bash

   ./tools/utils/aio-setup.sh

.. note:: You can set ``DEPLOY_K8S`` environment variable to ``false`` if you
   have a Kubernetes cluster and do not wish to deploy a new cluster when
   running the script.

.. note:: The script sets up a ``none``-driver minikube Kubernetes cluster and
   installs a version 3 ``helm`` executable. If you want to use your own cluster
   by setting ``DEPLOY_K8S`` to ``false``, you will need to ensure ``kubectl``
   and ``helm`` are available.


Script Completion
=================

The script should deploy a minikube Kubernetes node with Calico support enabled.
Further, it should deploy the following charts into its respective namespace:

+------------------------+-----------------------------+
| Chart                  | Namespace                   |
+========================+=============================+
| ``harbor``             | harbor                      |
+------------------------+-----------------------------+
| ``tekton-pipelines``   | tekton-pipelines            |
+------------------------+-----------------------------+
| ``tekton-dashboard``   | tekton-pipelines            |
+------------------------+-----------------------------+
| ``tekton-triggers``    | tekton-pipelines            |
+------------------------+-----------------------------+
| ``nfs-provisioner``    | nfs                         |
+------------------------+-----------------------------+
| ``grafana``            | grafana                     |
+------------------------+-----------------------------+
| ``loki``               | loki-stack                  |
+------------------------+-----------------------------+

.. code:: bash

   $ helm ls -A
   NAME            	NAMESPACE       	REVISION	UPDATED                                	STATUS  	CHART                 	APP VERSION
   grafana         	grafana         	1       	2020-12-18 10:05:44.266366139 -0600 CST	deployed	grafana-6.1.15        	7.3.3
   harbor          	harbor          	1       	2020-12-17 16:22:37.606705989 -0600 CST	deployed	harbor-1.5.2          	2.1.2
   loki            	loki-stack      	1       	2020-12-18 10:04:17.473045347 -0600 CST	deployed	loki-stack-2.2.0      	v2.0.0
   nfs-provisioner 	nfs             	1       	2020-12-17 16:22:34.450821264 -0600 CST	deployed	nfs-provisioner-0.1.1 	v2.2.1
   tekton-dashboard	tekton-pipelines	1       	2020-12-17 16:22:42.038851986 -0600 CST	deployed	tekton-dashboard-0.1.0	v0.10.1
   tekton-pipelines	tekton-pipelines	1       	2020-12-17 16:22:39.78742555 -0600 CST 	deployed	tekton-pipelines-0.1.0	v0.16.3
   tekton-triggers 	tekton-pipelines	1       	2020-12-17 16:22:40.750189048 -0600 CST	deployed	tekton-triggers-0.1.0 	v0.9.1

You can also inspect the pods and ensure they are all running:

.. code:: bash

   $ kubectl get pod -A
   NAMESPACE          NAME                                           READY   STATUS      RESTARTS   AGE
   grafana            grafana-58485fc6d5-s45d6                       1/1     Running     0          74s
   harbor             harbor-harbor-chartmuseum-5f7dccc958-kqq6n     1/1     Running     0          17h
   harbor             harbor-harbor-clair-b56498fcd-2tfl4            2/2     Running     4          17h
   harbor             harbor-harbor-core-7ccc475687-n9cbh            1/1     Running     0          17h
   harbor             harbor-harbor-database-0                       1/1     Running     0          17h
   harbor             harbor-harbor-jobservice-ddc4f6b49-c9cdz       1/1     Running     0          17h
   harbor             harbor-harbor-notary-server-6fd6567fc8-nb7zf   1/1     Running     1          17h
   harbor             harbor-harbor-notary-signer-7895b57c78-gw2tm   1/1     Running     1          17h
   harbor             harbor-harbor-portal-7d69b5598f-mj99d          1/1     Running     0          17h
   harbor             harbor-harbor-redis-0                          1/1     Running     0          17h
   harbor             harbor-harbor-registry-6755d8586b-p5mtp        2/2     Running     0          17h
   harbor             harbor-harbor-trivy-0                          1/1     Running     0          17h
   kube-system        calico-kube-controllers-675b7c9569-lntn4       1/1     Running     0          3d19h
   kube-system        calico-node-kpt5k                              1/1     Running     0          3d19h
   kube-system        coredns-f9fd979d6-zl5gp                        1/1     Running     0          3d19h
   kube-system        etcd-minikube                                  1/1     Running     0          3d19h
   kube-system        kube-apiserver-minikube                        1/1     Running     0          3d19h
   kube-system        kube-controller-manager-minikube               1/1     Running     0          3d19h
   kube-system        kube-proxy-pdpd9                               1/1     Running     0          3d19h
   kube-system        kube-scheduler-minikube                        1/1     Running     0          3d19h
   kube-system        storage-provisioner                            1/1     Running     0          3d19h
   loki-stack         loki-0                                         1/1     Running     0          2m41s
   loki-stack         loki-promtail-lmh7s                            1/1     Running     0          2m41s
   nfs                nfs-provisioner-7d749795c6-nbdzj               1/1     Running     0          17h
   tekton-pipelines   tekton-dashboard-5f8947b4cc-xhq4l              1/1     Running     0          17h
   tekton-pipelines   tekton-pipelines-controller-57866c7f56-4wkzt   1/1     Running     0          17h
   tekton-pipelines   tekton-pipelines-webhook-84c5494b44-cwmjx      1/1     Running     0          17h
   tekton-pipelines   tekton-triggers-controller-5f5dd8c885-jsv9k    1/1     Running     0          17h
   tekton-pipelines   tekton-triggers-webhook-55c6579868-8gcbf       1/1     Running     0          17h

Testing
=======

A basic suite of tests and helm tests can be executed by running:

.. code:: bash

   ./tools/gate/pipelines/run-test.sh
