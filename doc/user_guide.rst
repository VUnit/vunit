User Guide
==========

Introduction
------------
The idea in VUnit is to have a single point of entry for compiling and
running all tests within a HDL project. Tests do not need to be
manually added to some list as they are automatically detected. There
is no need for maintaining a list of files in compile order or
manually re-compile selected files after they have been edited as
VUnit automatically determines the compile order as well as which
files to incrementally re-compile. This is achieved by having a
``run.py`` file for each project where libraries are defined into
which files are added using the VUnit Python interface. The ``run.py``
file then acts as a command line utility for compiling and running
tests within the VHDL project.

Python Interface
----------------
The public interface of VUnit is exposed through the :class:`vunit.ui.VUnit` class
that can be imported directly from the :mod:`vunit <vunit.ui>` module. Read
:ref:`this <installing>` to make VUnit visible to Python.

.. code-block:: python
   :caption: Example ``run.py`` file.

   from vunit import VUnit

   # Create VUnit instance by parsing command line arguments
   vu = VUnit.from_argv()

   # Create library 'lib'
   lib = vu.add_library("lib")

   # Add all files ending in .vhd in current working directory
   lib.add_source_files("*.vhd")

   # Run vunit function
   vu.main()


Command Line Interface
----------------------
A :class:`VUnit <vunit.ui.VUnit>` object can be created from command
line arguments by using the :meth:`from_argv
<vunit.ui.VUnit.from_argv>` method effectively creating a custom
command line tool for running tests in the user project.  Source files
and libraries are added to the project by using methods on the VUnit
object. The configuration is followed by a call to the :meth:`main
<vunit.ui.VUnit.main>` method which will execute the function
specified by the command line arguments and exit the script. The added
source files are automatically scanned for test cases.

Usage
^^^^^

.. argparse::
   :ref: vunit.vunit_cli._parser_for_documentation
   :prog: run.py

.. _installing:

Installing
----------
To be able to import :class:`vunit.ui.VUnit` in your ``run.py`` script
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
   the VUnit root directory containing this user guide. Note that you
   shouldn't point to the vunit directory within the root directory.

3. Add the following to your ``run.py`` file **before** the ``import vunit``
   statement:

   .. code-block:: python

      import sys
      sys.path.append("/path/to/vunit_root/")
      import vunit
