-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;


entity tb_integer_vector_ptr_pool is
  generic (runner_cfg : string);
end entity;

architecture a of tb_integer_vector_ptr_pool is
begin
  main : process
    variable pool : integer_vector_ptr_pool_t;
    variable ptr, old_ptr, first_ptr : integer_vector_ptr_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test default pool is null") then
      assert pool = null_integer_vector_ptr_pool report "Expected null pool";

    elsif run("Test allocated ptr has length") then
      pool := new_integer_vector_ptr_pool;
      ptr := new_integer_vector_ptr(pool, 77);
      assert ptr /= null_ptr report "Expected non null ptr";
      check_equal(length(ptr), 77);
      recycle(pool, ptr);

    elsif run("Test recycled ptr is null") then
      pool := new_integer_vector_ptr_pool;
      ptr := new_integer_vector_ptr(pool);
      assert ptr /= null_ptr report "Expected non null ptr";
      recycle(pool, ptr);
      assert ptr = null_ptr report "Expected null ptr";

    elsif run("Test ptr is recycled") then
      pool := new_integer_vector_ptr_pool;
      ptr := new_integer_vector_ptr(pool, 2);
      old_ptr := ptr;
      recycle(pool, ptr);
      ptr := new_integer_vector_ptr(pool, 2);
      assert ptr = old_ptr report "Was recycled";

    elsif run("Test recycling beyond initial pool size") then
      pool := new_integer_vector_ptr_pool;
      first_ptr := new_integer_vector_ptr(pool, 2);
      for i in first_ptr.ref + 1 to first_ptr.ref + 1 + 2 ** 16 loop
        ptr := new_integer_vector_ptr(pool, 2);
        assert ptr.ref = i;
      end loop;
      for i in first_ptr.ref + 1 to first_ptr.ref + 1 + 2 ** 16 loop
        ptr.ref := i;
        recycle(pool, ptr);
      end loop;
      for i in first_ptr.ref + 1 + 2 ** 16 downto first_ptr.ref + 1 loop
        ptr := new_integer_vector_ptr(pool, 2);
        assert ptr.ref = i;
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
