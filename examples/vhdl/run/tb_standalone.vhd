-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_standalone is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_standalone is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that fails on VUnit check procedure") then
        check_equal(17, 18);
      elsif run("Test to_string for boolean") then
        check_equal(to_string(true), "true");
      end if;
    end loop;

    info("===Summary===" & LF & to_string(get_checker_stat));

    test_runner_cleanup(runner);
  end process;
end architecture;
