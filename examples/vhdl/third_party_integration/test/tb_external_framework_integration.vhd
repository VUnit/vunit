-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-------------------------------------------------------------------------------
-- This file shows how to integrate external assertion
-- libraries into VUnit. It can be a company proprietary
-- library or open source libraries such as OSVVM and UVVM
-------------------------------------------------------------------------------

library vunit_lib;
-- The VUnit run context doesn't include the logging and checking functionality
-- included in vunit_context. This will avoid some name collisions with other libraries.
context vunit_lib.vunit_run_context;

use std.textio.all;

entity tb_external_framework_integration is
  generic (runner_cfg : string := runner_cfg_default);
end entity tb_external_framework_integration;

architecture test_fixture of tb_external_framework_integration is
begin
  test_runner: process is
    ---------------------------------------------------------------------------
    -- Typical external framework functionality
    ---------------------------------------------------------------------------

    -- A concept for keeping track of error status
    variable error_counter : natural := 0;

    -- Assert procedures which may or may not stop the simulation on an error
    procedure external_assert (expr : boolean; msg : string; stop_on_error : boolean := true) is
      variable l : line;
    begin
      if not expr then
        write(l, "ERROR - " & msg);
        writeline(OUTPUT, l);

        error_counter := error_counter + 1;

        if stop_on_error then
          report "Simulation stopped due to errors" severity failure;
        end if;
      end if;
    end procedure external_assert;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that pass") then
        -- No special considerations for a passing test
        external_assert(true, "Error message");

      elsif run("Test that stops the simulation on first error") then
        -- VUnit will detect when an error stops the simulation
        external_assert(false, "Error message");

      elsif run("Test that doesn't stop the simulation on error") then
        -- When the test doesn't stop on error you must let VUnit know
        -- about the error state. This is done in the final test_runner_cleanup
        -- call
        external_assert(false, "Error message 1", false);
        external_assert(false, "Error message 2", false);
      end if;
    end loop;

    -- Add failure if external error counter > 0 which is not known to VUnit
    assert not (error_counter > 0) report "External failure" severity failure;

    test_runner_cleanup(runner);

  end process test_runner;
end;
