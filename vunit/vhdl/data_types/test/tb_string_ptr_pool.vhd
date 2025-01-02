-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.string_ptr_pkg.all;
use work.string_ptr_pool_pkg.all;

entity tb_string_ptr_pool is
  generic(runner_cfg : string);
end entity;

architecture a of tb_string_ptr_pool is
begin
  main : process
    variable pool : string_ptr_pool_t;
    variable ptr, old_ptr, first_ptr : string_ptr_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test default pool is null") then
      assert pool = null_string_ptr_pool report "Expected null pool";

    elsif run("Test new ptr has length") then
      pool := new_string_ptr_pool;
      ptr := new_string_ptr(pool, 77);
      assert ptr /= null_string_ptr report "Expected non null ptr";
      check_equal(length(ptr), 77);
      recycle(pool, ptr);

    elsif run("Test allocate string recycled") then
      pool := new_string_ptr_pool;
      ptr := new_string_ptr(pool, "hello");
      check_equal(to_string(ptr), "hello");
      old_ptr := ptr;
      recycle(pool, ptr);
      ptr := new_string_ptr(pool, "foobar");
      check_equal(to_string(ptr), "foobar");
      assert ptr = old_ptr report "Was recycled";

    elsif run("Test recycled ptr is null") then
      pool := new_string_ptr_pool;
      ptr := new_string_ptr(pool);
      assert ptr /= null_string_ptr report "Expected non null ptr";
      recycle(pool, ptr);
      assert ptr = null_string_ptr report "Expected null ptr";

    elsif run("Test ptr is recycled") then
      pool := new_string_ptr_pool;
      ptr := new_string_ptr(pool, 2);
      old_ptr := ptr;
      recycle(pool, ptr);
      ptr := new_string_ptr(pool, 2);
      assert ptr = old_ptr report "Was recycled";

    elsif run("Test recycling beyond initial pool size") then
      pool := new_string_ptr_pool;
      first_ptr := new_string_ptr(pool);
      for i in first_ptr.ref + 1 to first_ptr.ref + 1 + 2 ** 16 loop
        ptr := new_string_ptr(pool);
        assert ptr.ref = i;
      end loop;
      for i in first_ptr.ref + 1 to first_ptr.ref + 1 + 2 ** 16 loop
        ptr.ref := i;
        recycle(pool, ptr);
      end loop;
      for i in first_ptr.ref + 1 + 2 ** 16 downto first_ptr.ref + 1 loop
        ptr := new_string_ptr(pool);
        assert ptr.ref = i;
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
