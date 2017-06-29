-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.random_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_random is
  generic (runner_cfg : string);
end entity;

architecture a of tb_random is
begin
  main : process
    variable rnd : RandomPType;
    variable integer_vector_ptr, tmp : integer_vector_ptr_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test random integer_vector_ptr min max") then
      integer_vector_ptr := random_integer_vector_ptr(256, 10, 14);
      check_equal(length(integer_vector_ptr), 256);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) <= 14;
        assert get(integer_vector_ptr, i) >= 10;
      end loop;

      tmp := integer_vector_ptr;
      random_integer_vector_ptr(rnd, integer_vector_ptr, 13, 2, 4);
      check(tmp = integer_vector_ptr, "Reused pointer");
      check_equal(length(integer_vector_ptr), 13);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) <= 4;
        assert get(integer_vector_ptr, i) >= 2;
      end loop;
      deallocate(integer_vector_ptr);
    elsif run("Test random integer_vector_ptr num_bits is_signed") then
      integer_vector_ptr := random_integer_vector_ptr(100, num_bits => 10, is_signed => true);
      check_equal(length(integer_vector_ptr), 100);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) < 2**9;
        assert get(integer_vector_ptr, i) >= -2**9;
      end loop;

      random_integer_vector_ptr(rnd, integer_vector_ptr, 100, num_bits => 4, is_signed => false);
      check_equal(length(integer_vector_ptr), 100);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) < 2**4;
        assert get(integer_vector_ptr, i) >= 0;
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
