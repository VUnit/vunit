-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_stopping_failure is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_stopping_failure is
begin
  -- start_snippet tb_stopping_failure
  test_runner : process
    variable my_vector : integer_vector(1 to 17);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that fails on an assert") then
        assert false;
      elsif run("Test that crashes on boundary problems") then
        report to_string(my_vector(runner_cfg'length));
      elsif run("Test that fails on VUnit check procedure") then
        check_equal(17, 18);
      elsif run("Test that a warning passes") then
        assert false severity warning;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
  -- end_snippet tb_stopping_failure
end;
