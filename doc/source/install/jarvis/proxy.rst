=====================================
Running Jarvis Behind Corporate Proxy
=====================================

Environment Variables
=====================

On the host machine, ensure the following environment variables are set with the appropriate proxy information:
``HTTP_PROXY``, ``HTTPS_PROXY``, and ``NO_PROXY``. You will also need to set the environment variable ``PRIVATE_NS``
to an IP address of a corporate name server that will resolve internal URLs.

Vagrant Plugin
==============

To easily set up the Vagrant box's proxy setting, install the `vagrant_proxyconf`_ plugin by running:

.. code:: bash

  $ vagrant plugin install vagrant-proxyconf

``NO_PROXY`` Configuration
==========================

In the event ``NO_PROXY`` is not specified, the following default value will be used:

.. code::

  localhost,127.0.0.1,10.96.0.0/12,192.168.49.0/24,192.168.99.0/24,10.0.2.15,10.244.0.0/16,172.28.0.0/30,.minikube.internal,.svc,.svc.cluster.local,jarvis.local

Please note the following will need to be accounted for to avoid traffic being routed through the proxy:

- Localhost: ``localhost`` and ``127.0.0.1``,
- Host and guest machine IP and name: ``jarvis``, ``jarvis.local``, etc.,
- Minikube specific IP ranges (e.g. ``102.168.49.0/24``). See minikube's `documentation`_ for detail,
- Minikube places ``host.minikube.internal`` and ``control-plane.minikube.internal`` into ``/etc/hosts``,
- Kubernetes services' URLs with ending of ``.svc``, ``.cluster.local`` or ``.svc.cluster.local``,
- Kubernetes service cluster IP ranges: ``10.96.0.0/12`` or what's configured via ``--service-cluster-ip-range``.
- DNSMasq subnet range: ``172.28.0.0/30``

Installation
============

With the appropriate environment variables set, follow instruction :ref:`here <aio-installation>`.

.. _vagrant_proxyconf: http://tmatilai.github.io/vagrant-proxyconf/
.. _documentation: https://minikube.sigs.k8s.io/docs/handbook/vpn_and_proxy/
