-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- start_snippet tb_magic_paths
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_magic_paths is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_magic_paths is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    info("Directory containing testbench: " & tb_path(runner_cfg));
    info("Test output directory: " & output_path(runner_cfg));
    test_runner_cleanup(runner);
  end process;
end architecture;
-- end_snippet tb_magic_paths
