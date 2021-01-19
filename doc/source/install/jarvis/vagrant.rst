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


.. hint:: The recommended provider in the ``Vagrantfile`` is ``virtualbox``,
  however, ``libvirt`` is included.


.. note:: This document does not cover the installation of vagrant.
  Please refer to the instructions
  `here <https://www.vagrantup.com/docs/installation>`_.
