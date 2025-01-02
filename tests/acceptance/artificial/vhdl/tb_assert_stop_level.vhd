-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- This attribute should be ignored when VHDL assert stop level is used
-- vunit: fail_on_warning

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_assert_stop_level is
  generic (runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_assert_stop_level is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Report warning when VHDL assert stop level = warning") or
        run("Report warning when VHDL assert stop level = error") or
        run("Report warning when VHDL assert stop level = failure") then

        report "Warning" severity warning;
      elsif run("Report error when VHDL assert stop level = warning") or
        run("Report error when VHDL assert stop level = error") or
        run("Report error when VHDL assert stop level = failure") then

        report "Error" severity error;
      elsif run("Report failure when VHDL assert stop level = warning") or
        run("Report failure when VHDL assert stop level = error") or
        run("Report failure when VHDL assert stop level = failure") then

        report "Failure" severity failure;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
