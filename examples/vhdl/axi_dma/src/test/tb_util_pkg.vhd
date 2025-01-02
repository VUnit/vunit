-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library vunit_lib;
context vunit_lib.vunit_context;

use work.util_pkg.all;

entity tb_util_pkg is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_util_pkg is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    show(display_handler, pass);
    while test_suite loop
      if run("test clog2") then
        check_equal(clog2(1), 0);
        check_equal(clog2(2), 1);
        check_equal(clog2(3), 2);
        check_equal(clog2(4), 2);
        check_equal(clog2(5), 3);
        check_equal(clog2(8), 3);
        check_equal(clog2(127), 7);
        check_equal(clog2(128), 7);
        check_equal(clog2(129), 8);
        check_equal(clog2(2**30), 30);
      elsif run("test is_power_of_two") then
        check(is_power_of_two(1));
        check(is_power_of_two(2));
        check(is_power_of_two(4));
        check(is_power_of_two(2**30));
        check_false(is_power_of_two(3));
        check_false(is_power_of_two(2**30-1));
        check_false(is_power_of_two(2**30+1));
        check_false(is_power_of_two(integer'high));
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;
end;
