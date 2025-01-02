-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_magic_paths is
  generic (
    runner_cfg : string;
    tb_path : string;
    output_path : string);
end entity;

architecture vunit_test_bench of tb_magic_paths is
begin
  test_runner : process
    procedure check_has_suffix(value : string; suffix : string) is
    begin
      check_equal(value(value'length+1-suffix'length to value'length), suffix);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    check_has_suffix(tb_path, "/tests/acceptance/artificial/vhdl/");
    check_has_suffix(vunit_lib.run_pkg.tb_path(runner_cfg), "/tests/acceptance/artificial/vhdl/");
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
