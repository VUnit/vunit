-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_levels_pkg.all;

use vunit_lib.id_pkg.all;

entity tb_id is
  generic(runner_cfg : string);
end entity;

architecture a of tb_id is
begin
  test_runner : process
    variable id : id_t;
    constant my_id : id_t := new_id("my_id");
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that an uninitialized ID is invalid") then
        check_false(valid(id), result("for ID validity"));

      elsif run("Test that an initialized ID is valid") then
        check_true(valid(new_id), result("for ID validity"));
        check_true(valid(my_id), result("for ID validity"));

      elsif run("Test that an ID is named properly") then
        check_equal(name(new_id), "id 1");
        check_equal(name(my_id), "my_id", result("for my_id name"));

      elsif run("Test that two IDs cannot have the same name") then
        id := new_id("foo");
        mock(id_logger, error);
        id := new_id("foo");
        check_only_log(id_logger, "An ID named foo already exists.", error);
        unmock(id_logger);

      elsif run("Test that IDs are globally unique") then
        check(new_id /= new_id, result("for unnamed ID uniqueness"));

      elsif run("Test that IDs can be retrieved by name") then
        check(get_id("my_id") = my_id, result("for getting ID by name"));

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 15 ns);

end architecture;
