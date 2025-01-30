# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Shared simulation logic between vsim based simulators such as ModelSim
and RivieraPRO
"""

import sys
import os
from pathlib import Path
from ..ostools import write_file, Process
from ..test.suites import get_result_file_name
from ..persistent_tcl_shell import PersistentTclShell


class VsimSimulatorMixin(object):
    """
    A Mixin class for parts that are common to vsim/TCL based
    simulators such as modelsim and rivierapro
    """

    def __init__(self, prefix, persistent, sim_cfg_file_name):
        self._prefix = prefix
        sim_cfg_file_name = str(Path(sim_cfg_file_name).resolve())
        self._sim_cfg_file_name = sim_cfg_file_name

        prefix = self._prefix  # Avoid circular dependency inhibiting process destruction
        env = self.get_env()

        def create_process(ident):
            return Process(
                [
                    str(Path(prefix) / "vsim"),
                    "-c",
                    "-l",
                    str(Path(sim_cfg_file_name).parent / f"transcript{ident}"),
                    "-do",
                    str((Path(__file__).parent / "tcl_read_eval_loop.tcl").resolve()),
                ],
                cwd=str(Path(sim_cfg_file_name).parent),
                env=env,
            )

        if persistent:
            self._persistent_shell = PersistentTclShell(create_process=create_process)
        else:
            self._persistent_shell = None

    @staticmethod
    def _create_restart_function(optimize_design):
        """ "
        Create the vunit_restart function to recompile and restart the simulation

        This function is quite complicated to work around limitations
        of modelsim not being able to change working directory.

        Thus python is called with an explicit command string that in
        turn call the python command we actually wanted but in the
        correct working directory using subprocess.call

        -u flag is needed for continuous output
        """
        recompile_command = [sys.executable, "-u", sys.argv[0], "--compile"]

        # Strip --clean from re-compile command
        # Leave other arguments intact since users can add custom CLI options
        recompile_command += [arg for arg in sys.argv[1:] if arg != "--clean"]

        recompile_command_visual = " ".join(recompile_command)

        # stderr is intentionally re-directed to stdout so that the tcl's catch
        # relies on the return code from the python process rather than being
        # tricked by output going to stderr.  See issue #228.
        recompile_command_eval = [
            str(sys.executable),
            "-u",
            "-c",
            (
                "import sys;"
                "import subprocess;"
                f"exit(subprocess.call({recompile_command!r}, "
                f"cwd={str(Path(os.getcwd()).resolve())!r}, "
                "bufsize=0, "
                "universal_newlines=True, "
                "stdout=sys.stdout, "
                "stderr=sys.stdout))"
            ),
        ]
        recompile_command_eval_tcl = " ".join([f"{{{part}}}" for part in recompile_command_eval])

        tcl = f"""
proc vunit_compile {{}} {{
    set cmd_show {{{recompile_command_visual!s}}}
    puts "Re-compiling using command ${{cmd_show}}"

    set chan [open |[list {recompile_command_eval_tcl!s}] r]

    while {{[gets $chan line] >= 0}} {{
        puts $line
    }}

    if {{[catch {{close $chan}} error_msg]}} {{
        puts "Re-compile failed"
        puts ${{error_msg}}
        return true
    }} else {{
        puts "Re-compile finished"
        return false
    }}
}}
"""
        if optimize_design:
            tcl += """
proc vunit_restart {} {
    if {![vunit_compile]} {
        if {![vunit_optimize]} {
            _vunit_sim_restart
            vunit_run
        }
    }
}
"""
        else:
            tcl += """
proc vunit_restart {} {
    if {![vunit_compile]} {
        _vunit_sim_restart
        vunit_run
    }
}
"""
        return tcl

    def _create_common_script(self, test_suite_name, config, script_path, output_path, *, optimize_design):
        """
        Create tcl script with functions common to interactive and batch modes
        """
        tcl = """
proc vunit_help {} {
    puts {List of VUnit commands:}
    puts {vunit_help}
    puts {  - Prints this help}"""

        if not self._early_load_in_gui_mode():
            tcl += """
    puts {vunit_load [vsim_extra_args]}
    puts {  - Loads design with correct generics for the test(s)    }
    puts {  - Optional first argument are passed as extra flags to vsim}
    puts {  - Re-runs the user-defined after_load init file}"""
        else:
            tcl += """
    puts {vunit_load}
    puts {  - Re-runs the user-defined after_load init file}"""

        tcl += """
    puts {vunit_user_init}
    puts {  - Re-runs the user-defined GUI init file}
    puts {vunit_run}
    puts {  - Runs the user-defined before_load init file}
    puts {  - Runs the test(s)}
    puts {vunit_compile}
    puts {  - Re-compiles the source files}"""

        if optimize_design:
            tcl += """
    puts {vunit_optimize [vopt_extra_args]}
    puts {  - Re-optimizes the design. Must be done after vunit_compile}
    puts {  - Optional first argument are passed as extra flags to vopt}"""

        if optimize_design:
            tcl += """
    puts {vunit_restart}
    puts {  - Re-compiles the source files}
    puts {  - Re-optimizes the design if the compile was successful}
    puts {  - and re-runs the simulation if the compile and optimize were successful}"""
        else:
            tcl += """
    puts {vunit_restart}
    puts {  - Re-compiles the source files}
    puts {  - and re-runs the simulation if the compile was successful}"""

        tcl += """
}

proc vunit_run {} {
    if {[catch {_vunit_run} failed_or_err]} {
        echo $failed_or_err
        return true;
    }

    if {![is_test_suite_done]} {
        echo
        echo "Test Run Failed!"
        echo
        _vunit_run_failure;
        return true;
    }

    return false;
}

"""
        tcl += self._create_init_files_after_load(config)
        tcl += self._create_init_files_before_run(config)
        tcl += self._create_load_function(test_suite_name, config, script_path, optimize_design)
        tcl += get_is_test_suite_done_tcl(get_result_file_name(output_path))
        tcl += self._create_run_function()
        tcl += self._create_restart_function(optimize_design)

        if optimize_design:
            tcl += self._create_optimize_function(config)

        return tcl

    @staticmethod
    def _create_batch_script(common_file_name, load_only=False):
        """
        Create tcl script to run in batch mode
        """
        batch_do = ""
        batch_do += "onerror {quit -code 1}\n"
        batch_do += f'source "{fix_path(common_file_name)!s}"\n'
        batch_do += "set failed [vunit_load]\n"
        batch_do += "if {$failed} {quit -code 1}\n"
        if not load_only:
            batch_do += "set failed [vunit_run]\n"
            batch_do += "if {$failed} {quit -code 1}\n"
        batch_do += "quit -code 0\n"
        return batch_do

    def _create_init_files_after_load(self, config):
        """
        Create the _vunit_source_init_files_after_load function which sources the user defined TCL file in
        simulator_name.init_files.after_load
        """
        opt_name = self.name + ".init_files.after_load"
        init_files = config.sim_options.get(opt_name, [])
        tcl = "proc _vunit_source_init_files_after_load {} {\n"
        for init_file in init_files:
            tcl += self._source_tcl_file(init_file, config, opt_name)
        tcl += "    return 0\n"
        tcl += "}\n"
        return tcl

    def _create_init_files_before_run(self, config):
        """
        Create the _vunit_source_init_files_before_run function which sources the user defined TCL file in
        simulator_name.init_files.before_run
        """
        opt_name = self.name + ".init_files.before_run"
        init_files = config.sim_options.get(opt_name, [])
        tcl = "proc _vunit_source_init_files_before_run {} {\n"
        for init_file in init_files:
            tcl += self._source_tcl_file(init_file, config, opt_name)
        tcl += "    return 0\n"
        tcl += "}\n"
        return tcl

    def _create_user_init_function(self, config):
        """
        Create the vunit_user_init function which sources the user defined TCL file in
        simulator_name.init_file.gui
        """
        opt_name = self.name + ".init_file.gui"
        init_file = config.sim_options.get(opt_name, None)
        tcl = "proc vunit_user_init {} {\n"
        if init_file is not None:
            tcl += self._source_tcl_file(init_file, config, opt_name)
        tcl += "    return 0\n"
        tcl += "}\n"
        return tcl

    @staticmethod
    def _source_tcl_file(file_name, config, message):
        """
        Create TCL to source a file and catch errors
        Also defines the vunit_tb_path variable as the config.tb_path
        and the vunit_tb_name variable as the config.design_unit_name

        """
        template = """
    set vunit_tb_path "%s"
    set vunit_tb_name "%s"
    set file_name "%s"
    puts "Sourcing file ${file_name} from %s"
    if {[catch {source ${file_name}} error_msg]} {
        puts "Sourcing ${file_name} failed"
        puts ${error_msg}
        return true
    }
"""
        tcl = template % (
            fix_path(str(Path(config.tb_path).resolve())),
            config.design_unit_name,
            fix_path(str(Path(file_name).resolve())),
            message,
        )
        return tcl

    def _create_gui_script(self, common_file_name, config):
        """
        Create the user facing script which loads common functions and prints a help message
        """
        tcl = f'source "{fix_path(common_file_name)!s}"\n'
        tcl += self._create_user_init_function(config)
        tcl += "if {![vunit_load]} {\n"
        tcl += "  vunit_user_init\n"
        tcl += "  vunit_help\n"
        tcl += "}\n"

        return tcl

    def _run_batch_file(self, batch_file_name, gui=False, gui_option="-gui", extra_args=None):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """

        try:
            args = [
                str(Path(self._prefix) / "vsim"),
                gui_option if gui else "-c",
                "-l",
                str(Path(batch_file_name).parent / "transcript"),
                "-do",
                f'source "{fix_path(batch_file_name)!s}"',
            ]

            if extra_args:
                args += extra_args

            proc = Process(args, cwd=str(Path(self._sim_cfg_file_name).parent))
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def _run_persistent(self, common_file_name, load_only=False):
        """
        Run a test bench using the persistent vsim process
        """
        try:
            self._persistent_shell.execute(f'source "{fix_path(common_file_name)!s}"')
            self._persistent_shell.execute("set failed [vunit_load]")
            if self._persistent_shell.read_bool("failed"):
                return False

            run_ok = True
            if not load_only:
                self._persistent_shell.execute("set failed [vunit_run]")
                run_ok = not self._persistent_shell.read_bool("failed")
            self._persistent_shell.execute("quit -sim")
            return run_ok
        except Process.NonZeroExitCode:
            return False

    def _optimize_design(self, config):  # pylint: disable=unused-argument
        """
        Return True if design shall be optimized.
        """
        return False

    def _optimize(self, config, script_path):  # pylint: disable=unused-argument
        """
        Optimize design and return simulation target or False if optimization failed.
        """
        return False

    def _early_load_in_gui_mode(self):  # pylint: disable=unused-argument
        """
        Return True if design is to be loaded on the first vsim call rather than
        in the second vsim call embedded in the script file.

        This is required for Questa Visualizer.
        """
        return False

    def _get_load_flags(self, config, output_path, optimize_design):  # pylint: disable=unused-argument
        """
        Return extra flags needed for the first vsim call in GUI mode when early load is enabled.

        This is required for Questa Visualizer.
        """
        return []

    def _get_gui_option(self):
        """
        Return the option used to start in GUI mode.

        This is required to support Questa Visualizer.
        """
        return "-gui"

    def simulate(self, output_path, test_suite_name, config, elaborate_only):
        """
        Run a test bench
        """
        script_path = Path(output_path) / self.name

        common_file_name = script_path / "common.do"
        gui_file_name = script_path / "gui.do"
        batch_file_name = script_path / "batch.do"

        optimize_design = self._optimize_design(config)
        if optimize_design:
            if not self._optimize(config, script_path):
                return False

        write_file(
            str(common_file_name),
            self._create_common_script(
                test_suite_name, config, script_path, output_path, optimize_design=optimize_design
            ),
        )

        write_file(
            str(gui_file_name),
            self._create_gui_script(str(common_file_name), config),
        )
        write_file(
            str(batch_file_name),
            self._create_batch_script(str(common_file_name), elaborate_only),
        )

        if self._gui:
            early_load = self._gui and self._early_load_in_gui_mode()
            return self._run_batch_file(
                str(gui_file_name),
                gui=True,
                gui_option=self._get_gui_option(),
                extra_args=self._get_load_flags(config, output_path, optimize_design) if early_load else None,
            )

        if self._persistent_shell is not None:
            return self._run_persistent(str(common_file_name), load_only=elaborate_only)

        return self._run_batch_file(str(batch_file_name))


def fix_path(path):
    """
    Adjust path for TCL usage
    """
    return path.replace("\\", "/").replace(" ", "\\ ")


def get_is_test_suite_done_tcl(vunit_result_file):
    """
    Returns tcl procedure to detect if simulation was successful or not
    Simulation is considered successful if the test_suite_done was reached in the results file
    """
    return f"""
proc is_test_suite_done {{}} {{
    set fd [open "{fix_path(vunit_result_file)!s}" "r"]
    set contents [read $fd]
    close $fd
    set lines [split $contents "\n"]
    foreach line $lines {{
        if {{$line=="test_suite_done"}} {{
           return true;
        }}
    }}

    return false;
}}
"""
