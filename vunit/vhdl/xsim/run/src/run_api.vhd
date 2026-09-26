-- Run API package provides the common user API for all
-- implementations of the runner functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use work.run_types_pkg.all;
use work.types_pkg.all;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;

package run_pkg is

  shared variable current_test : line;

  constant test_suite : boolean := true;

  impure function enabled (
    constant name : string)
    return boolean;

  impure function run (
    constant name : string)
    return boolean;

  signal runner : runner_sync_t := (runner_event_idx => idle_runner,
                                    runner_exit_status_idx => runner_exit_with_errors,
                                    runner_timeout_update_idx => idle_runner,
                                    runner_timeout_idx => idle_runner);

  procedure test_runner_setup (
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default);

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    external_failure : boolean := false;
    allow_disabled_errors : boolean := false;
    allow_disabled_failures : boolean := false;
    fail_on_warning : boolean := false);

  procedure test_runner_watchdog (
    signal runner                    : inout runner_sync_t;
    constant timeout                 : in    time;
    constant do_runner_cleanup : boolean := true);

  impure function output_path (
    constant runner_cfg : string)
    return string;

end package;
