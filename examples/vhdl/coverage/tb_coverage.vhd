-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package pkg is
  attribute attr : string;
end package;

library vunit_lib;
context vunit_lib.vunit_context;


use work.pkg.attr;

entity tb_coverage is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_coverage is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    if false then
      report "Never reached";
    end if;

    if true then
      report "Hello";
    end if;
    test_runner_cleanup(runner); -- Simulation ends here
  end process;
end architecture;
