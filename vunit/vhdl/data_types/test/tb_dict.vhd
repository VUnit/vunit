-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.run_base_pkg.all;

use work.dict_pkg.all;

entity tb_dict is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_dict is
begin

  main : process
    variable dict : dict_t;
    constant many_keys : natural := 2**16;
    constant long_key : string := "long--------------------------------------------------------key";
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test default is null") then
      assert dict = null_dict report "expected null dict";

    elsif run("test new dict") then
      dict := new_dict;
      assert dict /= null_dict report "expected non-null dict";

    elsif run("test deallocate dict") then
      dict := new_dict;
      set(dict, "key", "value");
      deallocate(dict);
      assert dict = null_dict report "expected null dict";

    elsif run("test has key") then
      dict := new_dict;
      check_false(has_key(dict, "missing"));
      set(dict, "key", "value");
      check(has_key(dict, "key"));

    elsif run("test remove key") then
      dict := new_dict;

      set(dict, "key", "value");
      check(has_key(dict, "key"));
      check_equal(num_keys(dict), 1);

      remove(dict, "key");
      check_false(has_key(dict, "key"));
      check_equal(num_keys(dict), 0);

      remove(dict, "key");

    elsif run("test set and get") then
      dict := new_dict;
      set(dict, "key", "value");
      check_equal(get(dict, "key"), "value");

      set(dict, "key2", "value2");
      check_equal(get(dict, "key2"), "value2");

    elsif run("test overwrite key") then
      dict := new_dict;
      set(dict, "key", "value");
      check_equal(get(dict, "key"), "value");

      set(dict, "key", "value2");
      check_equal(get(dict, "key"), "value2");

    elsif run("test set and get many keys") then
      dict := new_dict;

      for k in 1 to 2 loop

        report integer'image(k);

        for i in 1 to many_keys loop
          set(dict, long_key & integer'image(i), integer'image(i));
          check_equal(get(dict, long_key & integer'image(i)), integer'image(i));
          check_equal(num_keys(dict), i);
        end loop;

        for i in 1 to many_keys loop
          check_equal(get(dict, long_key & integer'image(i)), integer'image(i));
        end loop;

        for i in many_keys downto 1 loop
          remove(dict, long_key & integer'image(i));
          check_equal(num_keys(dict), i-1);
        end loop;
      end loop;

      deallocate(dict);
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
