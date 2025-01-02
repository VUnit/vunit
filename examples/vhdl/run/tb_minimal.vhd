-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_minimal is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_minimal is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    check_equal(to_string(17), "17");
    test_runner_cleanup(runner);
  end process;
end architecture;
