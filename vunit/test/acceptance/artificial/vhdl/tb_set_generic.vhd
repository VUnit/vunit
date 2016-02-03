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

entity tb_set_generic is
  generic (
    runner_cfg : runner_cfg_t;
    is_ghdl : boolean;
    true_boolean : boolean;
    false_boolean : boolean;
    negative_integer : integer;
    positive_integer : integer;
    negative_real : real := 0.0;
    positive_real : real := 0.0;
    time_val : time := 0 ns;
    str_val : string;
    str_space_val : string;
    str_quote_val : string);
end entity;

architecture tb of tb_set_generic is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    assert true_boolean = true;
    assert false_boolean = false;
    assert negative_integer = -10000;
    assert positive_integer = 99999;
    if not is_ghdl then
      assert negative_real = -9999.9;
      assert positive_real = 2222.2;
      assert time_val = 4 ns;
    end if;
    assert str_val = "4ns";
    assert str_space_val = "1 2 3";
    assert str_quote_val = "a""b";
    test_runner_cleanup(runner);
  end process;
end architecture;
