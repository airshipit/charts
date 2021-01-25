==================
Jarvis AIO Vagrant
==================

.. _aio-installation:

Checkout Repository
===================

Checkout the Jarvis AIO repository using ``git``:

.. code:: bash

  git clone "https://review.opendev.org/airship/charts"

Installation
============

A vagrant file is provided under ``tools/deployment/vagrant``, running
``vagrant up`` from this directory should bring up and deploy a copy of the
Jarvis AIO.

.. note:: For Vagrant to work, a virtualization provider (e.g. ``Virtualbox``,
  ``libvirt``) is required. The recommended provider in the
  ``Vagrantfile`` is ``Virtualbox``, however, ``libvirt`` is included. To
  install ``Virtualbox``, see the instruction at
  `Virtualbox's page <https://www.virtualbox.org/>`_.


.. note:: This document does not cover the installation of vagrant.
  Please refer to the instructions at
  `Vagrant's page <https://www.vagrantup.com/docs/installation>`_.


Host Setup
==========

To access the exposed Jarvis services in the Vagrant box, update the
``/etc/hosts`` file with:

.. code::

  192.168.56.10 gerrit.jarvis.local harbor-core.jarvis.local harbor-notary.jarvis.local loki.jarvis.local grafana.jarvis.local

.. note:: Replace ``jarvis.local`` with the appropriate host and domain name if
  those are overwritten.
