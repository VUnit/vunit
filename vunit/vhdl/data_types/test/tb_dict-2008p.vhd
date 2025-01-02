-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

library ieee;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use work.dict_pkg.all;
use work.dict_2008p_pkg.all;
use work.queue_pkg.all;

entity tb_dict_2008p is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_dict_2008p is
begin

  main : process
    variable dict : dict_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test set and get boolean_vector") then
      dict := new_dict;
      set_boolean_vector(dict, "key", (false, true));
      check(get_boolean_vector(dict, "key") = (false, true));

    elsif run("test set and get time_vector") then
      dict := new_dict;
      set_time_vector(dict, "key", (17 ns, 21 ps));
      check(get_time_vector(dict, "key") = (17 ns, 21 ps));

    elsif run("test set and get real_vector") then
      dict := new_dict;
      set_real_vector(dict, "key", (17.17, 0.42));
      check(get_real_vector(dict, "key") = (17.17, 0.42));

    elsif run("test set and get integer_vector") then
      dict := new_dict;
      set_integer_vector(dict, "key", (17, 42));
      check(get_integer_vector(dict, "key") = (17, 42));

    elsif run("test set and get ufixed") then
      dict := new_dict;
      set_ufixed(dict, "key", to_ufixed(17.17, 6, -9));
      check(get_ufixed(dict, "key") = to_ufixed(17.17, 6, -9));

    elsif run("test set and get sfixed") then
      dict := new_dict;
      set_sfixed(dict, "key", to_sfixed(-21.21, 6, -9));
      check(get_sfixed(dict, "key") = to_sfixed(-21.21, 6, -9));

    elsif run("test set and get float") then
      dict := new_dict;
      set_float(dict, "key", to_float(17.17));
      check(get_float(dict, "key") = to_float(17.17));
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
