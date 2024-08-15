-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_fail_on_warning_from_python is
  generic (runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_fail_on_warning_from_python is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    report "A warning" severity warning;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
