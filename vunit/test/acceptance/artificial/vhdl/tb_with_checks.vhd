-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.lang.all;
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

entity tb_with_checks is
  generic (
    runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_with_checks is
begin
  test_runner : process
    variable stat : checker_stat_t := (0, 0, 0);
    variable pass : boolean;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test passing check") then
        wait for 10 ns;
        check(true, "Should pass");
      elsif run("Test failing check") then
        wait for 10 ns;
        check(false, "Should pass");
      elsif run("Test non-stopping failing check") then
        wait for 10 ns;
        check(false, "Should fail", level => warning);
      end if;
    end loop;

    get_checker_stat(stat);
    info("Result:" & LF & to_string(stat));

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
