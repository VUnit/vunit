-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.byte_vector_ptr_pkg.all;

entity tb_byte_vector_ptr is
  generic (runner_cfg : string);
end;

architecture a of tb_byte_vector_ptr is
begin
  main : process
    variable ptr, ptr2 : byte_vector_ptr_t;
    constant a_random_value : natural := 7;
    constant another_random_value : natural := 9;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("test_element_access") then
        ptr := new_byte_vector_ptr(1);
        set(ptr, 0, a_random_value);
        assert get(ptr, 0) = a_random_value;

        ptr2 := new_byte_vector_ptr(2);
        set(ptr2, 0, another_random_value);
        set(ptr2, 1, a_random_value);
        assert get(ptr2, 0) = another_random_value;
        assert get(ptr2, 1) = a_random_value;

        assert get(ptr, 0) = a_random_value report
          "Checking that ptr was not affected by ptr2";
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
