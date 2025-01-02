-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_other_file_tests is
  generic (
    runner_cfg : string);
end entity;

architecture vunit_test_bench of tb_other_file_tests is
begin
  tests : entity work.other_file_tests
    generic map (
       nested_runner_cfg => runner_cfg);
end architecture;
