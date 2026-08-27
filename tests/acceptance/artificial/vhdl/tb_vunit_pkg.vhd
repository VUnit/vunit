-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library foo_lib;
use foo_lib.foo_pkg.all;

entity tb_vunit_pkg is
  generic (runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_vunit_pkg is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    check(foo_pkg_is_present);
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
