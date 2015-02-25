-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library com_lib;
use com_lib.com_pkg.all;

entity tb_com is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity tb_com;

architecture test_fixture of tb_com is
begin
  test_runner : process
  begin
    checker_init(display_format => verbose,
                 file_name => join(output_path(runner_cfg), "error.csv"),
                 file_format => verbose_csv);    
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that an actor can be created") then
        check_failed("Not implemented");
      elsif run("Test that an actor can be destroyed") then
        check_failed("Not implemented");
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end test_fixture;
