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

.. note:: If running in a Windows machine, a common error is the incorrect carriage
   returns and symlinks not being created correctly when cloning your git repository.
   This can be fixed by doing the following:

   1. Run your editor in Administrator mode
   2. ``cd`` into your cloned git repository

   View all of the configurations for your git repository in step 3.
   Duplicates may show up in this list because this command shows ALL git config (system, global,
   local). Any config defined at the local level will take precedent over config at the system or
   global level. If the below commands do not work, keep in mind that these are the values that
   core.autocrlf and core.symlinks need to have in order to work.
   (If you set ``git config --global core.symlinks true``, and there is a local ``core.symlinks``
   defined to false, the false will take precedent.)

   3. Run ``git config --list``
   4. Run ``git config --global core.autocrlf false``
   5. Run ``git config core.symlinks true``
   6. Run ``git status``
   7. Run ``git restore tools/gate/jarvis/100-deploy-k8s.sh``
   8. Now proceed with the vagrant up command from the directory above


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
``/etc/hosts`` (``C:\Windows\System32\drivers\etc\hosts`` on Windows) file with:

.. code::

  192.168.56.10 gerrit.jarvis.local harbor-core.jarvis.local harbor-notary.jarvis.local loki.jarvis.local grafana.jarvis.local tekton.jarvis.local

.. note:: Replace ``jarvis.local`` with the appropriate host and domain name if
  those are overwritten.

If using a corporate VPN, then port forwarding is recommended. Instead of using ``192.168.56.10`` above, use ``127.0.0.1``. After running
``vagrant up``, open VirtualBox. Select the created VM. Click "Settings." Select the "Network" tab. Expand the "Advanced" section. Click the "Port Forwarding"
button. Add a new Port Forwarding Rule. Specify a host port of ``443`` and a guest port of ``443``. Click "Ok" to close "Port Forwarding Rules." Click "Ok" again
to close "Settings." Now, the above services should be accessible via a web browser once ``vagrant up`` is successful.
