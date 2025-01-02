-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_set_generic is
  generic (
    runner_cfg       : string;
    is_ghdl          : boolean;
    true_boolean     : boolean;
    false_boolean    : boolean;
    negative_integer : integer;
    positive_integer : integer;
    negative_real    : real := 0.0;
    positive_real    : real := 0.0;
    time_val         : time := 0 ns;
    str_val          : string;
    str_space_val    : string;
    str_quote_val    : string;
    str_long_num     : integer := 64;
    str_long_val     : string);
end entity;

architecture tb of tb_set_generic is
  impure function str_long(num: natural) return string is
    variable str: string(1 to 16*num);
  begin
    for x in 1 to num loop
      str((x-1)*16+1 to x*16) := "0123456789abcdef";
    end loop;
    return str;
  end;
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    assert true_boolean     = true;
    assert false_boolean    = false;
    assert negative_integer = -10000;
    assert positive_integer = 99999;
    if not is_ghdl then
      assert negative_real = -9999.9;
      assert positive_real = 2222.2;
      assert time_val      = 4 ns;
    end if;
    assert str_val       = "4ns";
    assert str_space_val = "1 2 3";
    assert str_quote_val = "a""b";
    assert str_long_val = str_long(str_long_num);
    test_runner_cleanup(runner);
  end process;
end architecture;
