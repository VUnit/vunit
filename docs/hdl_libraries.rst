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
   include = ["hdl/src/*.vhd"]

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
   include = ["hdl/src/*.vhd"]

Running the function takes both the package declaring it and the project allowing it:

.. code-block:: python

   vu.add_package("foo", allow_setup=True)

Adding a package declaring a setup function without ``allow_setup=True`` is an error naming the
function that would have run.
A package of nothing but VHDL never runs code of its own, and the Python code a project does allow
to run is visible in the run script rather than in a manifest the project never reads.

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

A package building something against the simulator installation itself has to know which one at setup
time, before any simulator interface exists to ask.
``context.simulator_class`` is the class of the selected simulator interface and
``context.simulator_name`` its name, both ``None`` when no simulator was found.
``context.simulator_prefix`` is the path the executables of that simulator were found in and
``context.simulator_backend`` says how the installation found there was built, which is simulator
specific: for GHDL it is its code generator, ``"mcode"``, ``"llvm"``, ``"llvm-jit"`` or ``"gcc"``,
and for a simulator with no such notion it is ``None``.

Simulator Hooks
---------------

The HDL code of a package can depend on something built outside the simulator, a native library or
generated files, and then the simulator typically has to be given extra options to find it: flags for
the elaboration of a test, flags for its simulation, flags for the simulator process VUnit starts or
environment variables.
``context.register_simulator_hooks(simulator_name, ...)`` registers, for one simulator, functions
returning those extras.
The hooks are called with the simulator interface such that what they return can depend on how the
simulator was configured and they only apply to the project they were registered for.
Here the flags give the simulator the search path of a library the package built and ask it to load
it:

.. code-block:: python
   :caption: foo/vunit_setup.py

   def setup(context):
       library = build_native_library(context.package_root / "c", context.output_path / "foo")

       context.register_simulator_hooks(
           "nvc",
           run_flags=lambda simulator_interface: [f"--load={library}"],
       )

       context.register_simulator_hooks(
           "ghdl",
           elab_flags=lambda simulator_interface: [f"-Wl,{library}"],
       )

There are four kinds of hooks, each used by the simulators for which it makes sense:

.. list-table::
   :header-rows: 1
   :widths: 20 45 35

   * - Hook
     - What it returns
     - Used by
   * - ``elab_flags(simulator_interface)``
     - Extra flags for the elaboration of a test.
     - GHDL, NVC and ModelSim/Questa, where they are given to ``vopt``.
   * - ``run_flags(simulator_interface)``
     - Extra flags for the simulation of a test.
     - All simulators. For the vsim based ones these reach the ``vsim`` command of the generated
       do-file, not the ``vsim`` process itself.
   * - ``process_flags(simulator_interface)``
     - Extra flags for the simulator process VUnit starts.
     - ModelSim/Questa and Riviera-PRO, for both the persistent and the batch ``vsim`` process.
   * - ``run_env(simulator_interface, env)``
     - The environment of the simulation, given the environment it would otherwise have.
     - GHDL, NVC and, for the ``vsim`` process, ModelSim/Questa and Riviera-PRO.

``run_flags`` and ``process_flags`` are separate because a vsim based simulator runs the simulation
from a script: ``run_flags`` extends the ``vsim`` command in that script, which is what options
selecting what to load into the simulation belong on, while ``process_flags`` extends the command line
of the ``vsim`` process VUnit starts, which is where an option affecting how that process itself is
set up has to go. Questa's ``-noautoldlibpath``, which keeps the bundled runtime libraries out of the
dynamic library search path, is only honoured there.

``process_flags`` and ``run_env`` are read when VUnit constructs the simulator interface, so they have
to be registered before that happens. A package registering them from its setup function is in time:
the setup function runs when :meth:`add_package() <vunit.ui.VUnit.add_package>` is called on the VUnit
object, which is before :meth:`main() <vunit.ui.VUnit.main>` creates the interface.

The simulator interface a hook is called with also tells how the simulator was found.
``simulator_interface.prefix`` is the path its executables were found in, the same the setup function
saw as ``context.simulator_prefix``.
``GHDLInterface.backend`` is the code generator of the GHDL used, ``"mcode"``, ``"llvm"``,
``"llvm-jit"`` or ``"gcc"``, which decides how a native library is bound to the design:
``"llvm"`` and ``"gcc"`` link it at elaboration while the others load it at run time.
A hook picks what to return from it:

.. code-block:: python
   :caption: foo/vunit_setup.py

   def elab_flags(simulator_interface):
       if simulator_interface.backend not in ("llvm", "gcc"):
           return []
       return [f"-Wl,-L{library.parent}"]

System Verilog
==============

Builtins
--------

See :meth:`add_verilog_builtins() <vunit.ui.VUnit.add_verilog_builtins>` and :vunit_file:`vunit_pkg.sv <vunit/verilog/vunit_pkg.sv>`.
