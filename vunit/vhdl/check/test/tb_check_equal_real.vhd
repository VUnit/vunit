-- This test suite verifies the check_equal checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;

use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;

entity tb_check_equal_real is
  generic (
    runner_cfg : string);
end entity;

architecture tb of tb_check_equal_real is
begin
  main : process
    variable my_checker : checker_t := new_checker("my_checker");
    variable my_logger : logger_t := get_logger(my_checker);

    constant real_0_0 : string := real'image(0.0);
    constant real_0_9 : string := real'image(0.9);
    constant real_1_0 : string := real'image(1.0);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test default checker") then
        mock(check_logger);
        check_equal(0.0, 0.0);
        check_only_log(check_logger, "Equality check passed - Got abs (" & real_0_0 & " - " & real_0_0 & ") <= " & real_0_0 & ".", pass);

        check_equal(0.0, 1.0, max_diff => 1.0);
        check_only_log(check_logger, "Equality check passed - Got abs (" & real_0_0 & " - " & real_1_0 & ") <= " & real_1_0 & ".", pass);

        check_equal(0.0, 1.0);
        check_only_log(check_logger, "Equality check failed - Got abs (" & real_0_0 & " - " & real_1_0 & ") > " & real_0_0 & ".", error);

        check_equal(0.0, 1.0, max_diff => 0.9);
        check_only_log(check_logger, "Equality check failed - Got abs (" & real_0_0 & " - " & real_1_0 & ") > " & real_0_9 & ".", error);
        unmock(check_logger);

      elsif run("Test custom checker") then
        mock(my_logger);
        check_equal(my_checker, 0.0, 0.0);
        check_only_log(my_logger, "Equality check passed - Got abs (" & real_0_0 & " - " & real_0_0 & ") <= " & real_0_0 & ".", pass);

        check_equal(my_checker, 0.0, 1.0, max_diff => 1.0);
        check_only_log(my_logger, "Equality check passed - Got abs (" & real_0_0 & " - " & real_1_0 & ") <= " & real_1_0 & ".", pass);

        check_equal(my_checker, 0.0, 1.0);
        check_only_log(my_logger, "Equality check failed - Got abs (" & real_0_0 & " - " & real_1_0 & ") > " & real_0_0 & ".", error);

        check_equal(my_checker, 0.0, 1.0, max_diff => 0.9);
        check_only_log(my_logger, "Equality check failed - Got abs (" & real_0_0 & " - " & real_1_0 & ") > " & real_0_9 & ".", error);
        unmock(my_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
