-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

entity tb_run is
  generic (
    runner_cfg : string;
    output_path : string);
end entity tb_run;

architecture tb of tb_run is
begin
  -- Instantiates tests in submodule to avoid unwanted scanning of if run("")
  -- This is since we are actually testing those functions themselves here not
  -- using them to test other things.
  tests : entity work.run_tests
    generic map (
      output_path => output_path);
end architecture;
