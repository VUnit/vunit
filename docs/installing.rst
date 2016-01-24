.. _installing:

Installing
==========
Using the Python Package Manager
--------------------------------
The recommended way to get VUnit is to **install the latest stable release** via `pip <https://pip.pypa.io/en/stable/>`__:

.. code-block:: console

   > pip install vunit_hdl


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
