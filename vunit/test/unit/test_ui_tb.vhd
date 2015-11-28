-- Log package provides the primary functionality of the logging library.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity test_ui_tb is
  generic (runner_cfg : runner_cfg_t);
end entity;

architecture tb of test_ui_tb is
begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    if run("test_one") then
      report "one";
    elsif run("test_two") then
      report "two";
    end if;
    test_runner_cleanup(runner);
  end process;
end architecture;
