-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

use work.pkg.all;

entity tb_pkg is
  generic (
    runner_cfg : string;
    value : integer);
end entity;

architecture a of tb_pkg is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    report integer'image(value);
    proc(value);
    test_runner_cleanup(runner);
  end process;
end architecture;
