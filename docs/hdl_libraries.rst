.. _hdl_libraries:

HDL Libraries
#############

VHDL
====

Builtins
--------

By default, VUnit provides bare minimal functionality for running testbenches.
In practice, most users want to use HDL utilities to reduce verbosity and improve reporting when writting tests.
VUnit includes several optional libraries in a group named *VHDL builtins* (see :meth:`add_vhdl_builtins() <vunit.ui.VUnit.add_vhdl_builtins>`):

* :vunit_file:`core <vunit/vhdl/core>`
* :vunit_file:`logging <vunit/vhdl/logging>` (see :ref:`logging_library`)
* :vunit_file:`string_ops <vunit/vhdl/string_ops>`
* :vunit_file:`check <vunit/vhdl/check>` (see :ref:`check_library`)
* :vunit_file:`dictionary <vunit/vhdl/dictionary>`
* :vunit_file:`run <vunit/vhdl/run>` (see :ref:`run_library`)
* :vunit_file:`path <vunit/vhdl/path>`

Most of the utilities are based on some internal data types providing dynamic arrays and queues (FIFOs).
See :ref:`data_types_library`.

Communication
-------------

The VUnit communication library (``com``) provides a high-level communication mechanism based on the
`actor model <http://en.wikipedia.org/wiki/Actor_model>`__.

See :meth:`add_com() <vunit.ui.VUnit.add_com>` and :ref:`com_user_guide`.

.. NOTE::
  The Communication Library depends on the builtins, which are added implicitly.

Verification Components
-----------------------

.. note:: This library is released as a *BETA* version. This means non-backwards compatible changes are still likely
  based on feedback from our users.

The VUnit Verification Component Library (VCL) contains a number of useful
:ref:`Verification Components <verification_components>` (VC) as well as a set of utilities for writing your own
verification component.
Verification components allow a better overview in the test bench by raising the abstraction level of bus transactions.
Even if you do not need the advanced features that VCs offer you may still benefit from using peer-verified models of an
AXI-bus instead of re-implementing it yourself.

See :meth:`add_verification_components() <vunit.ui.VUnit.add_verification_components>` and :ref:`vc_user_guide`.

.. NOTE::
  The VCL depends on both the Communication Library and OSVVM, which are added implicitly.

Random
------

VUnit provides random integer vector and pointer generation, based on built-in :ref:`Data Types <data_types_library>`
and OSVVM.

See :meth:`add_random() <vunit.ui.VUnit.add_random>`.

OSVVM
-----

VUnit includes the core of `OSVVM <https://github.com/osvvm/>`__ as a submodule and internal dependency of optional
libraries such as Random or Verification Components.
However, it can be added explicitly through :meth:`add_osvvm() <vunit.ui.VUnit.add_osvvm>`.

Moreover, multiple approaches are supported for using `OSVVMLibraries <https://github.com/OSVVM/OsvvmLibraries>`__ in
VUnit.
See :ref:`OSVB: Examples » SISO AXI4 Stream <osvb:Examples:AXI4Stream>`.

.. _packages:

Packages
========

HDL code can also be distributed as a Python package that VUnit adds with
:meth:`add_package() <vunit.ui.VUnit.add_package>`.
A package is an installed Python package containing a ``vunit_pkg.toml`` file in its root directory:

.. code-block:: toml
   :caption: vunit_pkg.toml

   [package]
   requires-vunit = ">=5.0.0"
   requires-vhdl = ">=2008"
   library = "foo_lib"

   [[package.sources]]
   include = ["src/*.vhd"]

The sources are compiled into the library named by ``library``, which is created by VUnit and owned by
the package.
``requires-vunit`` and ``requires-vhdl`` state the VUnit versions and the VHDL standards the package
supports.

Setup Function
--------------

Not everything a package needs to do can be expressed with a list of sources.
A package building a native library, generating sources or depending on simulator options
adds a ``setup`` key naming a ``"module:function"`` setup function:

.. code-block:: toml
   :caption: vunit_pkg.toml

   [package]
   library = "foo_lib"
   setup = "foo.vunit_setup:setup"

   [[package.sources]]
   include = ["src/*.vhd"]

VUnit imports the module and calls the function with a :class:`PackageContext <vunit.package_context.PackageContext>`
once the sources listed in the manifest have been added:

.. code-block:: python
   :caption: foo/vunit_setup.py

   def setup(context):
       build_dir = context.output_path / "foo"
       build_native_library(context.package_root / "c", build_dir)
       context.add_source_files("foo_lib", build_dir / "*.vhd")

The context provides the package root, the library created for the package, the VHDL standard used for
its sources, the VUnit output path, the path of the run script and the selected simulator.
Errors raised by the setup function are reported as an error for the package.

System Verilog
==============

Builtins
--------

See :meth:`add_verilog_builtins() <vunit.ui.VUnit.add_verilog_builtins>` and :vunit_file:`vunit_pkg.sv <vunit/verilog/vunit_pkg.sv>`.
