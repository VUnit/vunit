-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

-------------------------------------------------------------------------------
-- This is an example testbench using BVUL together with VUnit runner, check,
-- and log functionality. It is written with BVUL users in mind so the comments are
-- focused on describing VUnit behaviour. However, the information is kept
-- rather short, for more information you should read the user guides, primarily
--
-- * user_guide.md under the VUnit root
-- * <VUnit root>/vhdl/check/user_guide.md
-- * <VUnit root>/vhdl/logging/user_guide.md
--
-- The user guides are Markdown documents. If you don't have a Markdown viewer
-- you can read the rendered versions on https://github.com/VUnit/vunit
--
-- For simplicity there is no DUT in this testbench, focus is on describing BVUL
-- and VUnit integration.
--
-- The testbench can be run directly with your simulator like a "traditional"
-- BVUL testbench but the preferred way is to run with the VUnit run script,
-- run_bvul.py, in the parent directory of this file (<root>). There are some
-- differences in behavior when running in the different modes. This is
-- described at the end of this file (see Running w/wo Script).
--
-- In this testbench BVUL logging/reporting calls like
--
-- log("\nChecking Register defaults"); -- progress report
-- report_alert_counters(FINAL); -- final summary report
--
-- have been excluded. The reason is that run_bvul.py will handle reporting for you.
-- More information about what's reported by run_bvul.py and what you can add to the
-- VHDL code if you want to is described at the end of this file (see VHDL and
-- Python Reporting).
--
-- When using VUnit with BVUL there is a risk of name collisions when using the
-- warning, error, and failure procedures. These procedures are not used in this
-- testbench but a solution to handle this potential problem is given at the
-- end of this file (Handling Name Collisions)
-------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.textio.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library bitvis_util;
use bitvis_util.types_pkg.all;
use bitvis_util.string_methods_pkg.all;
use bitvis_util.adaptations_pkg.all;
use bitvis_util.methods_pkg.all;
use bitvis_util.vhdl_version_layer_pkg.get_alert_counter;

entity tb_bvul_integration is
  generic (
    -- This generic is used to configure the testbench from run_bvul.py, e.g. what
    -- test case to run. The default value is used when not running from script
    -- and in that case all test cases are run.
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity tb_bvul_integration;

architecture test_fixture of tb_bvul_integration is
  signal output_data : unsigned(9 downto 0) := to_unsigned(144,10);
  signal grant : std_logic_vector(1 downto 0) := "10";
begin
  test_runner: process is
    variable expected_data : integer;
  begin
    -- Setup the VUnit runner with the input configuration.
    test_runner_setup(runner, runner_cfg);

    -- To avoid that log files from different test cases (run in separate
    -- simulations) overwrite each other run_bvul.py provides separate test case
    -- directories through the runner_cfg generic (<root>/vunit_out/tests/<test case
    -- name>). When not using run_bvul.py the default path is the current directory
    -- (<root>/vunit_out/<simulator>). These directories are used by VUnit
    -- itself and these lines make sure that BVUL do to.
    set_log_file_name(join(output_path(runner_cfg), "_Log.txt"));
    set_alert_file_name(join(output_path(runner_cfg), "_Alert.txt"));

    -- The default behavior for VUnit is to stop the simulation on a failing
    -- check when running from script but keep on running when running without
    -- script. The rationale for this and how you can change that behavior is
    -- described at the bottom of this file (see Stopping the Simulation on
    -- Failing Checks). The following if statement causes BVUL checks to behave
    -- in the same way.
    if not active_python_runner(runner_cfg) then
      set_alert_stop_limit(ERROR, 0);
    end if;

    -- The VUnit runner loops over the enabled test cases in the test suite.
    -- When using run_bvul.py only one test case is enabled in each simulation.
    while test_suite loop
      -- Each test case is defined by a branch in the if statement. This test
      -- suite has four test cases, two using VUnit checking and two using BVUL
      -- checking.
      if run("Test data path with VUnit") then
        expected_data := 13 ** 2;
        -- check_equal is one of VUnit's around 15 check types. It checks the equality
        -- between two values and is similar to BVUL's check_value. The
        -- difference here is that check_equal handles equality between different and
        -- commonly compared types. With preprocessor support VUnit can also
        -- handle all types of relations between values of any type. See check_relation
        -- in the check user guide for more info.
        check_equal(output_data, expected_data, "Data path error.");
      elsif run("Test bus status with VUnit") then
        -- check is the VUnit integrated version of the assert statement in
        -- VHDL. It simply checks if a boolean expression is true.
        check(grant /= "11" , "Must not grant simultaneous access.");
      elsif run("Test data path with BVUL") then
        expected_data := 13 ** 2;
        check_value(output_data, to_unsigned(expected_data, output_data'length), ERROR, "Data path error.");
      elsif run("Test bus status with BVUL") then
        check_value(grant /= "11" , ERROR, "Must not grant simultaneous access.");
      end if;
    end loop;

    -- Cleanup VUnit. The BVUL error status is imported into VUnit at this
    -- point. This is neccessary when the BVUL alert stop limit is set such that
    -- BVUL doesn't stop on the first error. In that case VUnit has no way of
    -- knowing the error status unless you tell it.
    test_runner_cleanup(runner, get_alert_counter(ERROR) > 0);
    wait;
  end process test_runner;
end;

-- Running w/wo Script
-- ===================
--
-- The default behaviour when running your testbench with the run_bvul.py script
-- is to run each test case in a separate simulation which means that the test
-- case is free from interference from other test cases. So when a test case
-- fails you know that the root cause is within that test case and not a side
-- effect of previous test cases. Also, with independent test cases you can run
-- selected test cases in a test suite (see python run_bvul.py -h), test cases can
-- be run in parallel on many cores to reduce test time (see -p option), and
-- the risk of having to change many test cases just because you wanted to make
-- changes to one is reduced.
-- There's a small sub-second overhead associated with each test case when doing
-- this. If this is important to you there is an option to override this with
-- the run_all_in_same_sim pragma. See the last line of
-- vhdl/com/test/tb_com.vhd for an example.


-- Handling Name Collisions
-- ========================
--
-- Calling any of the three procedures warning, error, and failure with a
-- single string parameter causes compiler problems since definitions are
-- available from both VUnit and BVUL. VUnit provides these as convenience
-- procedures for creating log entries at the given severity level. Writing
--
-- error("Something is wrong");
--
-- is equivalent to
--
-- log("Something is wrong", error);
--
-- Although a failing check can generate such a message the error call isn't
-- the same thing. It's just an error message and doesn't affect error
-- statistics, it doesn't go into the error log that checks may use and so on.
-- If that's what you want you should use the unconditional check
--
-- check_failed("Something is wrong");
--
-- Because of this the VUnit warning, error, and failure procedures aren't
-- normally found in a testbench.
--
-- BVUL handles this differently, the error call above is a convinience procedure
-- for BVUL's unconditional check
--
-- alert(ERROR, "Something is wrong");
--
-- As such it's more likely to be used in a BVUL style testbench. If that is
-- the case there are a number of options. For example,
--
-- * Don't use error, use alert instead
-- * Use the selected name bitvis_util.methods_pkg.error
-- * Make a shorter alias like bvul_error of the selected name
-- * Instead of using vunit_context you can use vunit_run_context
--   which allows you to create a VUnit style testbench that can be automated
--   by run_bvul.py but it doesn't give access to VUnit check and log functionality
--   so there are no name collisions.


-- Stopping the Simulation on Failing Checks
-- =========================================
--
-- Whether or not to stop a simulation on VUnit detected errors is
-- controlled by the global stop level and the severity of a failing check. The
-- simulation stops if severity >= stop level. The default stop level is
-- failure and the default severity of a check is error so by default a
-- failing check doesn't stop the simulation. HOWEVER, the
-- test_runner_setup procedure changes the stop level to error IF the
-- testbench is called from script (it knows about this from runner_cfg).
-- So when running from script it will stop on error.
--
-- The reason for this behavior is that the goal of a run is to find out ALL
-- the passing/failing test cases in the test suite. The only way to do this
-- without scripting is to keep running on an error unless the severity of that
-- error is such that there is no point in trying to proceed. Severity level
-- failure is intended to express that level of severity which means that the
-- default error level keeps the simulation running. The major drawback to this
-- approach is that it may be hard to prevent the error state of a failing test
-- case from causing secondary effects in following test cases and a misleading
-- pass/fail report in the end.
--
-- The Python scripting default behaviour is to restart the
-- simulation after a stop caused by a failing check and then continue
-- with the next test case which means that it can achieve the goal of a
-- complete pass/fail report and at the same time also prevent error state
-- propagation. So stopping on error severity is a good strategy when
-- running from script.
--
-- However, if you want the simulation to stop when running
-- without script as well you can do that by changing the stop_level like this
--
-- checker_init(stop_level => error);
--
-- or the default severity of checks like this
--
-- checker_init(default_level => failure);
--
-- or raise the severity of specific checks with an extra parameter to the
-- call.
--
-- check(foo = bar, "Expected foo to be equal bar", failure);


-- VHDL and Python Reporting
-- =========================
--
-- Preferred VUnit usage is to do the "simulate everything" runs using the
-- run_bvul.py script. The script will report what test case is running, if it passed
-- or failed, error message and call stack if it fails, and a summary at the end.
-- If you have a failing test case you can start that in the GUI for debugging
-- (see run_bvul.py -h). When running the single test case in the GUI there is no
-- need for progress and summary reporting.
-- If you still want the VHDL to generate this kind of information you can enable the
-- embedded runner_trace_logger and filter out everything but info messages to get
-- progress reporting for currently running test case. Read the log user guide for
-- details on how to do this. A final report can be created by using the
-- get_checker_stat function. Read the check user guide for more information.
