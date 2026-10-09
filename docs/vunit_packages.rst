.. _vunit_packages:

VUnit Packages
##############

HDL code can be distributed as a Python package and added to a VUnit project
with :meth:`add_package() <vunit.ui.VUnit.add_package>`.

A VUnit package must be installed and importable, and its root directory must
contain a ``vunit_pkg.toml`` manifest. Namespace packages are not currently
supported.

To use a package, add it in the project's run script:

.. code-block:: python

   from vunit import VUnit

   vu = VUnit.from_argv()
   vu.add_vhdl_builtins()
   vu.add_package("foo")
   vu.main()

The manifest specifies the package's source files, version requirements,
and compilation defaults. For example:

.. code-block:: toml
   :caption: vunit_pkg.toml

   [package]
   requires-vunit = ">=5.0.0.dev14"
   requires-vhdl = ">=2008,<2019"
    requires = 'simulator != "xsim" or vhdl >= "2019"'
   library = "foo_lib"
   compile_option = [["<option-name>", ["<value>"]]]

   [[package.sources]]
   include = ["hdl/src/*.vhd"]

   [[package.sources]]
   include = ["hdl/compat/*.vhd"]
   library = "foo_compat"
   compile_option = [["<option-name>", ["<source-value>"]]]

Each ``[[package.sources]]`` table defines a source entry. Its ``files``
patterns (or the backwards-compatible ``include`` key) are relative to the
package root. In this example, files matching ``hdl/src/*.vhd`` use the
default library, ``foo_lib``, while files matching ``hdl/compat/*.vhd`` use
``foo_compat``.

A source entry can be restricted to matching environments:

.. code-block:: toml

  [[package.sources]]
  library = "foo_lib"
  files = ["hdl/vhdl2019/*.vhd"]
  when = 'vhdl >= "2019"'

Replace the compile-option placeholders with names and values supported by
the project. Each option is a two-element array containing the option name
and an array of string values. Package-level options apply to every source
entry. A source-level option overrides the package-level option with the
same name for that entry.

The supported manifest fields are:

.. list-table::
   :header-rows: 1
   :widths: 24 20 56

   * - Field
     - Location
     - Meaning
   * - ``requires-vunit``
     - ``[package]``
     - VUnit version constraints that the project must satisfy.
   * - ``requires-vhdl``
     - ``[package]``
     - Constraints on the VHDL standards supported by the package.
   * - ``requires``
     - ``[package]``
     - Environment expression that must match before the package can be used.
   * - ``library``
     - ``[package]``
     - Default library for package sources. Required when ``sources`` is
       present. VUnit creates the library for the package.
   * - ``sources``
     - ``[[package.sources]]``
     - Repeated source tables. Each table must contain ``files`` or
       ``include``, an array of source patterns relative to the package root.
   * - ``when``
     - ``[[package.sources]]``
     - Optional environment expression that controls whether this source
       entry is included.
   * - ``library``
     - ``[[package.sources]]``
     - Optional library override for this source entry. VUnit creates the
       library if needed.
   * - ``compile_option``
     - ``[package]`` or ``[[package.sources]]``
     - Array of option-name/value-array pairs. Source-level options override
       package-level options with the same name.
   * - ``setup``
     - ``[package]``
     - Optional Python setup function, specified as ``"module:function"``.
       See :ref:`package_setup_function`.

The ``requires-vunit`` and ``requires-vhdl`` fields accept comma-separated
comparisons using ``<=``, ``<``, ``!=``, ``==``, ``>=``, or ``>``. All
comparisons must be satisfied. For example, ``">=2008,<2019"`` allows
VHDL 2008 but excludes VHDL 2019 and later standards.

If the project's VHDL standard does not satisfy ``requires-vhdl``, VUnit
selects a compatible supported standard and issues a warning. If no such
standard is available, adding the package fails. A VUnit version that does
not satisfy ``requires-vunit`` always causes an error.

The optional ``requires`` and ``when`` expressions support marker names
``vunit``, ``vhdl``, ``simulator``, and the simulator version markers
``activehdl_version``, ``ghdl_version``, ``modelsim_version``,
``nvc_version``, and ``rivierapro_version``. Version markers are available
only when their corresponding simulator is selected. Equality and inequality
checks on an unavailable version marker are supported, but ordering checks
are unavailable. With no simulator selected, equality and inequality checks
on ``simulator`` are supported, but ordering checks are unavailable. Values
are quoted strings, comparisons use
``<=``, ``<``, ``!=``, ``==``, ``>=``, or ``>``, and ``and``, ``or``, and
parentheses group comparisons. ``and`` has higher precedence than ``or``.
The legacy ``requires-vunit`` and ``requires-vhdl`` constraints remain in
force alongside ``requires``. A source entry without ``when`` is always
included for a usable package.

Manifest validation is strict: unknown fields and values of the wrong type
are rejected.

Publishing
==========

It is recommended to publish VUnit packages on PyPI and add the ``vunitpkg``
keyword to the package metadata in ``pyproject.toml``. This makes VUnit
packages easier to identify and discover:

.. code-block:: toml

  [project]
  keywords = ["vunitpkg"]

.. _package_setup_function:

Setup Function
==============

Packages can be defined entirely in `vunit_pkg.toml`. For packages that need additional setup, such as building a
native library, generating sources, or configuring simulator options, the optional `setup` key specifies a Python
function in the format `"module:function"`:

.. code-block:: toml
   :caption: vunit_pkg.toml

   [package]
   library = "foo_lib"
   setup = "foo.vunit_setup:setup"

   [[package.sources]]
   include = ["hdl/src/*.vhd"]

The project must explicitly allow the setup function to run:

.. code-block:: python

   vu.add_package("foo", allow_setup=True)

If a package declares a setup function and ``allow_setup=True`` is not
provided, adding the package fails with an error identifying the function
that would have run. This makes permission to execute package setup code
explicit in the project's run script. Packages that only list HDL sources
do not need a setup function.

After adding the sources listed in the manifest, VUnit imports the specified
module and calls the setup function with a
:class:`PackageContext <vunit.package_context.PackageContext>`:

.. code-block:: python
   :caption: foo/vunit_setup.py

   def setup(context):
       build_dir = context.output_path / "foo"
       build_native_library(context.package_root / "c", build_dir)
       context.add_source_files("foo_lib", build_dir / "*.vhd")

The context provides the package root, the default library created for the package,
the VHDL standard used for its sources, the VUnit output path, the run script
path, and information about the selected simulator. Exceptions raised by
the setup function are reported as package errors.

A package that builds against a simulator installation needs information
about that installation during setup, before VUnit creates the simulator
interface. The context exposes this information through the following
attributes:

* ``context.simulator_class`` is the selected simulator interface class.
* ``context.simulator_name`` is the selected simulator's name.
* ``context.simulator_prefix`` is the directory containing the selected
  simulator's executables.
* ``context.simulator_backend`` identifies the installation's backend,
  where applicable. For GHDL, this is the code generator: ``"mcode"``,
  ``"llvm"``, ``"llvm-jit"``, or ``"gcc"``. For simulators without a backend
  distinction, it is ``None``.

Both ``simulator_class`` and ``simulator_name`` are ``None`` when no simulator
is found.

Simulator Hooks
===============

A package's HDL sources may depend on a native library or generated files.
The simulator may need additional flags or environment variables to locate
and use these dependencies.

Use ``context.register_simulator_hooks(simulator_name, ...)`` to register
functions that supply these settings for a particular simulator. Hooks
receive the simulator interface, so they can adapt their results to its
configuration. They apply only to the project in which they are registered.

The following example builds a native library and registers hooks to load
it with NVC or link it with GHDL:

.. code-block:: python
   :caption: foo/vunit_setup.py

   def setup(context):
       library = build_native_library(
           context.package_root / "c",
           context.output_path / "foo",
       )

       context.register_simulator_hooks(
           "nvc",
           run_flags=lambda simulator_interface: [f"--load={library}"],
       )

       context.register_simulator_hooks(
           "ghdl",
           elab_flags=lambda simulator_interface: [f"-Wl,{library}"],
       )

The GHDL hook above assumes a backend that links native libraries during
elaboration. Backend-specific hooks are described below.

Four hook types are available, with support depending on the simulator:

.. list-table::
   :header-rows: 1
   :widths: 20 45 35

   * - Hook
     - Return value
     - Supported simulators
   * - ``elab_flags(simulator_interface)``
     - Additional flags for test elaboration.
     - GHDL, NVC, and ModelSim/Questa. ModelSim/Questa passes these flags
       to ``vopt``.
   * - ``run_flags(simulator_interface)``
     - Additional flags for test simulation.
     - All simulators. For simulators based on ``vsim``, these flags are
       added to the ``vsim`` command in the generated do-file.
   * - ``process_flags(simulator_interface)``
     - Additional command-line flags for the simulator process started
       by VUnit.
     - ModelSim/Questa and Riviera-PRO, for both persistent and batch
       ``vsim`` processes.
   * - ``run_env(simulator_interface, env)``
     - The simulation environment, based on the environment supplied
       in ``env``.
     - GHDL and NVC, and the ``vsim`` process for ModelSim/Questa and
       Riviera-PRO.

For simulators based on ``vsim``, ``run_flags`` and ``process_flags`` target
different commands:

* ``run_flags`` adds options to the ``vsim`` command inside the generated
  do-file. Use it for options that control what is loaded into the simulation.
* ``process_flags`` adds options to the command line used to start the
  ``vsim`` process. Use it for options that configure the process itself.

For example, Questa's ``-noautoldlibpath`` option prevents bundled runtime
libraries from being added to the dynamic library search path. It is only
honoured on the process command line, so it belongs in ``process_flags``.

VUnit evaluates ``process_flags`` and ``run_env`` when it constructs the
simulator interface. These hooks must therefore be registered before the
interface is created. Registering them in a package setup function meets
this requirement: setup runs during
:meth:`add_package() <vunit.ui.VUnit.add_package>`, before
:meth:`main() <vunit.ui.VUnit.main>` creates the interface.

Hooks can also inspect the simulator installation through the interface
they receive. The ``simulator_interface.prefix`` attribute contains the
directory of the simulator executables, matching
``context.simulator_prefix`` from the setup function.

For GHDL, ``GHDLInterface.backend`` identifies the code generator:
``"mcode"``, ``"llvm"``, ``"llvm-jit"``, or ``"gcc"``. This determines how
native libraries are bound to the design. The ``"llvm"`` and ``"gcc"``
backends link them during elaboration; the other backends load them at
runtime.

A hook can use this information to return flags only for the relevant
backends. For example, with ``library`` referring to the built native
library, this hook adds a linker search path only for ``"llvm"`` and
``"gcc"``:

.. code-block:: python
   :caption: foo/vunit_setup.py

   def elab_flags(simulator_interface):
       if simulator_interface.backend not in ("llvm", "gcc"):
           return []
       return [f"-Wl,-L{library.parent}"]