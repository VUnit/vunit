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

entity tb_same_sim_some_fail is
  generic (
    runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_same_sim_some_fail is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test 1") then
        wait for 10 ns;
        report "Test 1";
      elsif run("Test 2") then
        wait for 10 ns;
        report "Test 2";
        assert false;
      elsif run("Test 3") then
        wait for 10 ns;
        report "Test 3";
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;

-- vunit_pragma run_all_in_same_sim
