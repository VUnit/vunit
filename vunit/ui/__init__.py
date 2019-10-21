# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-lines

"""
.. autoclass:: vunit.ui.VUnit()
   :members:
   :exclude-members: add_preprocessor,
      add_builtins

.. autoclass:: vunit.ui.Library()
   :members:
   :exclude-members: package

.. autoclass:: vunit.ui.SourceFileList()
   :members:

.. autoclass:: vunit.ui.SourceFile()
   :members:

.. autoclass:: vunit.ui.TestBench()
   :members:

.. autoclass:: vunit.ui.Test()
   :members:

.. autoclass:: vunit.ui.Results()
   :members:

.. _compile_options:

Compilation Options
-------------------
Compilation options allow customization of compilation behavior. Since simulators have
differing options available, generic options may be specified through this interface.
The following compilation options are known.

``ghdl.flags``
   Extra arguments passed to ``ghdl -a`` command during compilation.
   Must be a list of strings.

``incisive.irun_vhdl_flags``
   Extra arguments passed to the Incisive ``irun`` command when compiling VHDL files.
   Must be a list of strings.

``incisive.irun_verilog_flags``
   Extra arguments passed to the Incisive ``irun`` command when compiling Verilog files.
   Must be a list of strings.

``modelsim.vcom_flags``
   Extra arguments passed to ModelSim ``vcom`` command.
   Must be a list of strings.

``modelsim.vlog_flags``
   Extra arguments passed to ModelSim ``vlog`` command.
   Must be a list of strings.

``rivierapro.vcom_flags``
   Extra arguments passed to Riviera PRO ``vcom`` command.
   Must be a list of strings.

``rivierapro.vlog_flags``
   Extra arguments passed to Riviera PRO ``vlog`` command.
   Must be a list of strings.

``activehdl.vcom_flags``
   Extra arguments passed to Active HDL ``vcom`` command.
   Must be a list of strings.

``activehdl.vlog_flags``
   Extra arguments passed to Active HDL ``vcom`` command.
   Must be a list of strings.

.. note::
   Only affects source files added *before* the option is set.

.. _sim_options:

Simulation Options
-------------------
Simulation options allow customization of simulation behavior. Since simulators have
differing options available, generic options may be specified through this interface.
The following simulation options are known.

``vhdl_assert_stop_level``
  Will stop a VHDL simulation for asserts on the provided severity level or higher.
  Valid values are ``"warning"``, ``"error"``, and ``"failure"``. This option takes
  precedence over the fail_on_warning attribute.

``disable_ieee_warnings``
  Disable ieee warnings. Must be a boolean value. Default is False.

.. _coverage:

``enable_coverage``
  Enables code coverage collection during simulator for the run affected by the sim_option.
  Must be a boolean value. Default is False.

  When coverage is enabled VUnit only takes the minimal steps required
  to make the simulator creates an unique coverage file for the
  simulation run. The VUnit users must still set :ref:`sim
  <sim_options>` and :ref:`compile <compile_options>` options to
  configure the simulator specific coverage options they want. The
  reason for this to allow the VUnit users maximum control of their
  coverage settings.

  An example of a ``run.py`` file using coverage can be found
  :vunit_example:`here <vhdl/coverage>`.

  .. note: Supported by RivieraPRO and Modelsim/Questa simulators.


``pli``
  A list of PLI file names.

``ghdl.flags``
   Extra arguments passed to ``ghdl --elab-run`` command *before* executable specific flags.
   Must be a list of strings.

``incisive.irun_sim_flags``
   Extra arguments passed to the Incisive ``irun`` command when loading the design.
   Must be a list of strings.

``modelsim.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``modelsim.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``modelsim.vsim_flags``.
   Must be a list of strings.

``modelsim.init_files.after_load``
   A list of user defined DO/TCL-files that is sourced after the design has been loaded.
   They will be executed during ``vunit_load``, after the top level has been loaded
   using the ``vsim`` command.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a list of strings.

``modelsim.init_files.before_run``
   A list of user defined DO/TCL-files that is sourced before the simulation is run.
   They will be executed at the start of ``vunit_run`` (and therefore also re-executed
   by ``vunit_restart``).
   Must be a list of strings.

``modelsim.init_file.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a string.

``rivierapro.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``rivierapro.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``rivierapro.vsim_flags``.
   Must be a list of strings.

``rivierapro.init_files.after_load``
   A list of user defined DO/TCL-files that is sourced after the design has been loaded.
   They will be executed during ``vunit_load``, after the top level has been loaded
   using the ``vsim`` command.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a list of strings.

``rivierapro.init_files.before_run``
   A list of user defined DO/TCL-files that is sourced before the simulation is run.
   They will be executed at the start of ``vunit_run`` (and therefore also re-executed
   by ``vunit_restart``).
   Must be a list of strings.

``rivierapro.init_file.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a string.

``activehdl.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``activehdl.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``activehdl.vsim_flags``.
   Must be a list of strings.

``activehdl.init_file.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer.
   Must be a string.

``ghdl.elab_flags``
   Extra elaboration flags passed to ``ghdl --elab-run``.
   Must be a list of strings.

``ghdl.sim_flags``
   Extra simulation flags passed to ``ghdl --elab-run``.
   Must be a list of strings.

``ghdl.elab_e``
   With ``--elaborate``, execute ``ghdl -e`` instead of ``ghdl --elab-run --no-run``.
   Must be a boolean.

``ghdl.gtkwave_script.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer. Must be a string.
   There are currently limitations in the HEAD revision of GTKWave that prevent the
   user from sourcing a list of scripts directly. The following is the current work
   around to sourcing multiple user TCL-files:
   ``source <path/to/script.tcl>``

.. |compile_option| replace::
   The name of the compile option (See :ref:`Compilation options <compile_options>`)

.. |simulation_options| replace::
   The name of the simulation option (See :ref:`Simulation options <sim_options>`)

.. _configurations:

Configurations
--------------
In VUnit Python API the name ``configuration`` is used to denote the
user controllable configuration of one test run such as
generic/parameter settings, simulation options as well as the
pre_config and post_check :ref:`callback functions <pre_and_post_hooks>`.
User :ref:`attributes <attributes>` can also be added as a part of a
configuration.

Configurations can either be unique for each test case or must be
common for the entire test bench depending on the situation.  For test
benches without test such as `tb_example` in the User Guide the
configuration is common for the entire test bench. For test benches
containing tests such as `tb_example_many` the configuration is done
for each test case. If the ``run_all_in_same_sim`` attribute has been used
configuration is performed at the test bench level even if there are
individual test within since they must run in the same simulation.

In a VUnit all test benches and test cases are created with an unnamed default
configuration which is modified by different methods such as ``set_generic`` etc.
In addition to the unnamed default configuration multiple named configurations
can be derived from it by using the ``add_config`` method. The default
configuration is only run if there are no named configurations.

.. |configurations| replace::
    :ref:`configurations <configurations>`
"""
