-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

entity tb_ieee_warning is
  generic (runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_ieee_warning is
begin
  test_runner : process
    variable undefined : unsigned(15 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("pass") then
        report integer'image(to_integer(undefined));

      elsif run("fail") then
        report integer'image(to_integer(undefined));
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;

-- vunit_pragma fail_on_warning
