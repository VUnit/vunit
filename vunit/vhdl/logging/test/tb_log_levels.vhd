-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;

use work.log_levels_pkg.all;
use work.core_pkg.all;
use work.test_support_pkg.all;
use work.checker_pkg.all;
use work.ansi_pkg.all;

entity tb_log_levels is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_log_levels is
begin
  main : process
    variable level : log_level_t;
  begin

    test_runner_setup(runner, runner_cfg);

    if run("Default levels have correct names") then
      assert_equal(get_name(trace), "trace");
      assert_equal(get_name(debug), "debug");
      assert_equal(get_name(info), "info");
      assert_equal(get_name(warning), "warning");
      assert_equal(get_name(error), "error");
      assert_equal(get_name(failure), "failure");

      assert_true(log_level_t'low < trace);
      assert_true(trace < debug);
      assert_true(debug < info);
      assert_true(info < log_level_t'(warning));
      assert_true(log_level_t'(warning) < log_level_t'(error));
      assert_true(log_level_t'(error) < log_level_t'(failure));
      assert_true(log_level_t'(failure) < log_level_t'high);

      assert_true(is_valid(trace));
      assert_true(is_valid(debug));
      assert_true(is_valid(info));
      assert_true(is_valid(warning));
      assert_true(is_valid(error));
      assert_true(is_valid(failure));

    elsif run("Can create level") then
      level := new_log_level("my_level");
      assert_equal(get_name(level), "my_level");
      assert(get_color(level) = (fg => no_color, bg => no_color, style => normal));

      level := new_log_level("my_level2", fg => red, bg => yellow, style => bright);
      assert(get_color(level) = (fg => red, bg => yellow, style => bright));

    elsif run("Can create max num custom levels") then
      for i in 0 to max_num_custom_log_levels - 1 loop
        level := new_log_level("my_level" & integer'image(i));
        assert_true(is_valid(level));
        assert_equal(get_name(level), "my_level" & integer'image(i));
      end loop;

    elsif run("Error on undefined level") then
      mock_core_failure;
      assert get_name(custom_level2) = "custom_level2";
      check_core_failure("Use of undefined level custom_level2.");
      unmock_core_failure;

    elsif run("Max name length") then
      level := new_log_level("a_long_log_level_name");
      assert_equal(max_level_length, 21);
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
