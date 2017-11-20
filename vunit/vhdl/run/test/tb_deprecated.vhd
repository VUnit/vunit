-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com
-------------------------------------------------------------------------------
-- This testbench verifies deprecated interfaces
-------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.run_deprecated_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;

entity tb_deprecated is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_deprecated is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test legacy test_runner_cleanup") then
        mock(default_logger);
        test_runner_cleanup(runner, (0, 0, 0));
        check_log(
          default_logger,
          "Using deprecated procedure test_runner_cleanup with checker_stat input." & LF &
          "Non-default checkers with failed checks will be recognized without feeding its" & LF &
          "statistics to test_runner_cleanup",
          warning);
        unmock(default_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
