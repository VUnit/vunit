-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

-------------------------------------------------------------------------------
-- This is an example testbench using BVUL together with VUnit runner
-- functionality. For simplicity there is no DUT, focus is on describing BVUL
-- and VUnit integration.
--
-- The testbench can be run directly with your simulator like a "traditional"
-- BVUL testbench or it can be run with the VUnit run script, run_1.py, in the root
-- directory (parent to the directory of this file). There are some differences
-- in behavior when running in the different modes. When running from run_1.py
-- each test case will run in a separate simularion and is free from
-- interference from other test cases. So when a test case fails you know that the
-- root cause is within that test case and not a side effect of previous test
-- cases. Also, with independent test cases you can run selected test cases in
-- a test suite (see python run.py -h), test cases can be run in parallel on
-- many cores to reduce test time (see -p option), and the risk of having to
-- change many test cases just because you wanted to make changes to one is reduced.
-------------------------------------------------------------------------------


-- VUnit testbenches normally use the vunit_context which includes
-- logging and checking functionality overlapping that of BVUL. There are also
-- name collisions between the two libraries. One way of handling this is to
-- exclude the VUnit logging and checking functionality by using the
-- vunit_run_context instead. One of the other testbenches in this directory
-- shows how functionality from both can be mixed.
library vunit_lib;
context vunit_lib.vunit_run_context;

library bitvis_util;
use bitvis_util.types_pkg.all;
use bitvis_util.string_methods_pkg.all;
use bitvis_util.adaptations_pkg.all;
use bitvis_util.methods_pkg.all;
use bitvis_util.vhdl_version_layer_pkg.get_alert_counter;

entity tb_1_bvul_with_vunit_runner is
  generic (
    -- This generic is used to configure the testbench from run.py, e.g. what
    -- test case to run. The default value is used when not running from script
    -- and in that case all test cases are run.
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity tb_1_bvul_with_vunit_runner;

architecture test_fixture of tb_1_bvul_with_vunit_runner is
begin
  test_runner: process is
  begin
    -- Setup the VUnit runner with the input onfiguration.
    test_runner_setup(runner, runner_cfg);

    -- When using run_1.py the configuration will contain a separate output
    -- directory for each test case (<root>/vunit_out/tests/<test case name>) where
    -- you can put your log files. When not using run.py the default path is
    -- the current directory (<root>/vunit_out/<simulator>).
    set_log_file_name(join(output_path(runner_cfg), "_Log.txt"));
    set_alert_file_name(join(output_path(runner_cfg), "_Alert.txt"));

    -- Default BVUL (and VUnit) behaviour is to stop the simulation on the first
    -- error. It's still possible to run from script if you decide to delay
    -- simulation stop on error. Uncomment the line below to prevent BVUL from
    -- stopping on errors.

    -- set_alert_stop_limit(ERROR, 0);

    -- The VUnit runner loops over the enabled test cases in the test suite.
    -- When using run_1.py only one test case is enabled in each simulation.
    while test_suite loop
      -- Each test case is defined by a branch in the if statement.
      if run("Test should fail") then
        -- Within the branch you write your BVUL style test code as you would
        -- normally do. The first log statement is to show progress when
        -- running without script. When running with script from command line
        -- it will show progress anyway. It's also possible to get progress
        -- within the simulation without explicit log statements. However, that
        -- involves making use of the VUnit log statements which we have
        -- excluded from this testbench. This is showed in one of the other
        -- example testbenches.
        log(ID_LOG_HDR, "Test should fail");
        check_value(false, ERROR, "This was an expected failure");
      elsif run("Test should pass") then
        log(ID_LOG_HDR, "Test should pass");
        check_value(true, ERROR, "Was not expecting this to fail");
      end if;
    end loop;

    -- Report BVUL result
    report_alert_counters(FINAL);

    -- Cleanup VUnit. The BVUL error status is imported into VUnit at this
    -- point. This is neccessary when the BVUL alert stop limit is set such that
    -- BVUL doesn't stop on the first error. In that case VUnit has no way of
    -- knowing the error status unless you tell it.
    test_runner_cleanup(runner, get_alert_counter(ERROR) > 0);
    wait;
  end process test_runner;
end;
