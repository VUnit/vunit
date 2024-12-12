.. _compile_options:

Compilation Options
-------------------

Compilation options allow customization of compilation behavior. Since simulators have
differing options available, generic options may be specified through this interface.
The following compilation options are known.

``ghdl.a_flags``
   Extra arguments passed to ``ghdl -a`` command during compilation.
   Must be a list of strings.

``incisive.irun_vhdl_flags``
   Extra arguments passed to the Incisive ``irun`` command when compiling VHDL files.
   Must be a list of strings.

``incisive.irun_verilog_flags``
   Extra arguments passed to the Incisive ``irun`` command when compiling Verilog files.
   Must be a list of strings.

``modelsim.vcom_flags``
   Extra arguments passed to ModelSim ``vcom`` command when compiling VHDL files.
   Must be a list of strings.

``modelsim.vlog_flags``
   Extra arguments passed to ModelSim ``vlog`` command when compiling Verilog files.
   Must be a list of strings.

``nvc.a_flags``
   Extra arguments passed to ``nvc -a`` command during compilation.
   Must be a list of strings.

``nvc.global_flags``
   Extra global arguments to pass to ``nvc`` before the ``-a`` command.
   Must be a list of strings.

``rivierapro.vcom_flags``
   Extra arguments passed to Riviera PRO ``vcom`` command when compiling VHDL files.
   Must be a list of strings.

``rivierapro.vlog_flags``
   Extra arguments passed to Riviera PRO ``vlog`` command when compiling Verilog files.
   Must be a list of strings.

``activehdl.vcom_flags``
   Extra arguments passed to Active HDL ``vcom`` command when compiling VHDL files.
   Must be a list of strings.

``activehdl.vlog_flags``
   Extra arguments passed to Active HDL ``vcom`` command when compiling Verilog files.
   Must be a list of strings.

``enable_coverage``
   Enables compilation flags needed for code coverage and tells VUnit to handle
   the coverage files created at compilation. Only used for coverage with GHDL.
   Must be a boolean value. Default is False.

.. note::
   Only affects source files added *before* the option is set.

.. _sim_options:

Simulation Options
------------------

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
  to make the simulator create a unique coverage file for the
  simulation run.

  For RiverieraPRO and Modelsim/Questa, the VUnit users must still set :ref:`sim
  <sim_options>` and :ref:`compile <compile_options>` options to
  configure the simulator specific coverage options they want. The
  reason for this to allow the VUnit users maximum control of their
  coverage settings.

  For GHDL with GCC backend there is less configurability for coverage, and all
  necessary flags are set by the ``enable_coverage`` sim and compile options.

  An example of a ``run.py`` file using coverage can be found
  :vunit_example:`here <vhdl/coverage>`.

  .. note: Supported by GHDL with GCC backend, RivieraPRO and Modelsim/Questa simulators.


``pli``
  A list of PLI file names.

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
   Additionally, the ``vunit_tb_name`` variable is defined as the name of the test bench.
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
   Additionally, the ``vunit_tb_name`` variable is defined as the name of the test bench.
   Must be a string.

``modelsim.three_step_flow``
   Enable 3-step flow where a separate ``vopt`` step is executed before ``vsim`` is called.
   Must be a boolean value. Default is False.

``modelsim.vopt_flags``
   Extra arguments passed to ``vopt`` when ``modelsim.three_step_flow`` is ``True``.
   Must be a list of strings.

``modelsim.vsim_flags.gui``
   Extra arguments passed to ``vopt`` when ``modelsim.three_step_flow`` is ``True`` and
   GUI mode is enabled. Takes precedence over ``modelsim.vopt_flags``. Must be a list of
   strings.

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
   Additionally, the ``vunit_tb_name`` variable is defined as the name of the test bench.
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
   Additionally, the ``vunit_tb_name`` variable is defined as the name of the test bench.
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
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Additionally, the ``vunit_tb_name`` variable is defined as the name of the test bench.
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

``ghdl.viewer.gui``
   Name of waveform viewer to use. The command line argument ``--viewer`` will have
   precedence if provided. If neither is provided, ``gtkwave`` or ``surfer`` will be
   used.

``ghdl.viewer_script.gui``
   A user defined file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer. Must be a string.

   There are currently limitations in the HEAD revision of GTKWave that prevent the
   user from sourcing a list of scripts directly. The following is the current work
   around to sourcing multiple user TCL-files:
   ``source <path/to/script.tcl>``

``nvc.elab_flags``
   Extra elaboration flags passed to ``nvc -e``.
   Must be a list of strings.

``nvc.global_flags``
   Extra global arguments to pass to ``nvc`` before the ``-e`` or ``-r``
   commands.
   Must be a list of strings.

``nvc.heap_size``
   Simulation heap size.
   Must be a string, for example ``"64m"``.

``nvc.sim_flags``
   Extra simulation flags passed to ``nvc -r``.
   Must be a list of strings.

``nvc.viewer.gui``
   Name of waveform viewer to use. The command line argument ``--viewer`` will have
   precedence if provided. If neither is provided, ``gtkwave`` or ``surfer`` will be
   used.

``nvc.viewer_script.gui``
   A user defined file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer. Must be a string.

   There are currently limitations in the HEAD revision of GTKWave that prevent the
   user from sourcing a list of scripts directly. The following is the current work
   around to sourcing multiple user TCL-files:
   ``source <path/to/script.tcl>``
