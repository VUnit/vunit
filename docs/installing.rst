.. _installing:

Installing
==========
Using the Python Package Manager
--------------------------------
The recommended way to get VUnit is to **install the latest stable release** via `pip <https://pip.pypa.io/en/stable/>`__:

.. code-block:: console

   > pip install vunit_hdl

Once installed, VUnit may be updated to new versions via a similar method:

.. code-block:: console

   > pip install -U vunit_hdl


Using the Development Version
-----------------------------
Start by cloning our `GIT repository on GitHub <https://github.com/vunit/vunit/>`__:

.. code-block:: console

   git clone https://github.com/VUnit/vunit.git

To be able to import :class:`VUnit <vunit.ui.VUnit>` in your ``run.py`` script
you need to make it visible to Python or else the following error
occurs.

.. code-block:: console

   Traceback (most recent call last):
      File "run.py", line 2, in <module>
        from vunit import VUnit
   ImportError: No module named vunit

There are three methods to make VUnit importable in your ``run.py`` script.:

1. Install it in your Python environment using:

   .. code-block:: console

      > python setup.py install

2. Set the ``PYTHONPATH`` environment variable to include the path to
   the VUnit repository root directory. Note that you shouldn't point
   to the vunit directory within the root directory.

3. Add the following to your ``run.py`` file **before** the ``import vunit``
   statement:

   .. code-block:: python

      import sys
      sys.path.append("/path/to/vunit_repo_root/")
      import vunit

For VUnit Developers
~~~~~~~~~~~~~~~~~~~~
For those interested in development of VUnit, it is best to install
VUnit so that the sources from git are installed in-place instead of
to the Python site-packages directory. This can be achieved by using
the ``-e`` flag with ``pip``, or the ``develop`` option with
``setup.py``, or setting the ``PYTHONPATH`` environment variable.

   .. code-block:: console

      > git clone https://github.com/VUnit/vunit.git
      > cd vunit

      > python setup.py develop
      or
      > pip install -e .

By installing VUnit in this manner, the git sources can be edited directly in
your workspace while the ``VUnit`` package is still globally available in your
Python environment.
