-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;

entity tb_magic_paths is
  generic (
    runner_cfg : runner_cfg_t;
    tb_path : string;
    output_path : string);
end entity;

architecture vunit_test_bench of tb_magic_paths is
begin
  test_runner : process

    procedure check_equal(got, expected : string) is
    begin
      assert got = expected report "Got '" & got & "' expected '" & expected & "'";
    end procedure;

    procedure check_has_suffix(value : string; suffix : string) is
    begin
      check_equal(value(value'length+1-suffix'length to value'length), suffix);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    check_has_suffix(tb_path, "acceptance/artificial/vhdl/");
    check_has_suffix(output_path, "acceptance/artificial out/tests/lib.tb_magic_paths/");
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
