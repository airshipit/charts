===================================
Requirements and Host Configuration
===================================

Overview
========

Below are some instructions and suggestions to help you get started with a All-in-One environment on Ubuntu 20.04.
Other supported versions of Linux can also be used, with the appropriate changes to package installation.

Requirements
============

System Requirements
-------------------

The recommended minimum system requirements for a full deployment are:

- 8GB of RAM
- 4 Cores
- 48GB HDD

This guide covers the minimum number of requirements to get started.

All commands below should be run as a normal user, not as root.
Appropriate versions of Docker, Kubernetes, and Helm will be installed
by the scripts used below, so there's no need to install them ahead of time.

.. warning:: By default the Calico CNI will use ``192.168.0.0/16`` and
   Kubernetes services will use ``10.96.0.0/16`` as the CIDR for services. Check
   that these CIDRs are not in use on the development node before proceeding, or
   adjust as required.

Host Configuration
------------------

Utilities on the hosts, need to be able to resolve kubernetes services correctly.
Ubuntu Desktop and some other distributions make use of ``mdns4_minimal`` which
does not operate as Kubernetes expects with its default TLD of ``.local``. To operate
as expected either change the ``hosts`` line in the ``/etc/nsswitch.conf``, or confirm
that it matches:

.. code-block:: ini

  hosts:          files dns