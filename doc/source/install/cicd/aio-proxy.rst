===============================
All-In-One Behind HTTP(S) Proxy
===============================

.. note::
  If you are **not** deploying the All-In-One (AIO) behind a proxy, you
  can skip this page.

.. hint::
  Set the environment variables: ``HTTP_PROXY``, ``HTTPS_PROXY``, and ``NO_PROXY``.

By default, AIO will use Google DNS Server IPs (``8.8.8.8`` and ``8.8.4.4``)
and will update ``/etc/resolv.conf`` as a result. If those IPs are blocked by
your proxy, running the AIO script will result in the inability to connect to
anything on the network.

.. literalinclude:: ../../../../tools/gate/deploy-k8s.sh
    :language: shell
    :lines: 33-43
    :caption: ``resolv.conf`` setting

In the case this is run behind a proxy, specifying the proxy informatin
in the environment variable ``$HTTP_PROXY`` will reserve the nameserver
in ``/etc/resolv.conf``.

To ensure minikube has the appropriate proxy information, set the environment
variables: ``HTTP_PROXY``, ``HTTPS_PROXY``, and ``NO_PROXY`` with the
appropriate strings. Minikube would be started with the correct docker
environment variable set.

.. literalinclude:: ../../../../tools/gate/deploy-k8s.sh
    :language: shell
    :lines: 112-118
    :caption: minikube proxy setting

.. note::
  Depending on your specific proxy, ``https_proxy`` may be the same as ``http_proxy``.
  Refer to your specific proxy documentation.
