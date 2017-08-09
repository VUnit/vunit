-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;

use work.log_levels_pkg.all;
use work.core_pkg.all;
use work.assert_pkg.all;

entity tb_log_levels is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_log_levels is
begin
  main : process
    variable level : log_level_t;
    variable count : natural;
  begin

    test_runner_setup(runner, runner_cfg);

    if run("Default levels have correct names") then
      assert_equal(get_name(verbose), "verbose");
      assert_equal(get_name(debug), "debug");
      assert_equal(get_name(info), "info");
      assert_equal(get_name(warning), "warning");
      assert_equal(get_name(error), "error");
      assert_equal(get_name(failure), "failure");

      assert_true(below_all_log_levels < verbose);
      assert_true(verbose < debug);
      assert_true(debug < info);
      assert_true(info < log_level_t'(warning));
      assert_true(log_level_t'(warning) < log_level_t'(error));
      assert_true(log_level_t'(error) < log_level_t'(failure));
      assert_true(log_level_t'(failure) < above_all_log_levels);

      assert_true(is_valid(verbose));
      assert_true(is_valid(debug));
      assert_true(is_valid(info));
      assert_true(is_valid(warning));
      assert_true(is_valid(error));
      assert_true(is_valid(failure));

    elsif run("Can create level") then
      level := new_log_level("my_level", 23);
      assert_equal(get_name(level), "my_level");
      assert_true(level = custom_level23);

    elsif run("Can create level relative to other level") then
      level := new_log_level("my level", info + 3);
      assert_true(level = custom_level48);
      level := new_log_level("my level 2", level + 3);
      assert_true(level = custom_level51);

      level := new_log_level("my level 3", info - 3);
      assert_true(level = custom_level42);
      level := new_log_level("my level 4", level - 3);
      assert_true(level = custom_level39);

    elsif run("Can create max num custom levels") then
      count := 0;
      for lvl in numeric_log_level_t'low to numeric_log_level_t'high loop
        level := log_level_t'val(lvl);

        case level is
          when verbose|debug|info|warning|error|failure =>
            assert_true(is_valid(level));
          when others =>
            assert_false(is_valid(level));
            level := new_log_level("my_level" & integer'image(lvl), lvl);
            assert_true(is_valid(level));
            assert_equal(get_name(level), "my_level" & integer'image(lvl));
            count := count + 1;
        end case;
      end loop;
      assert_equal(count, numeric_log_level_t'high - numeric_log_level_t'low - 6 + 1);

    elsif run("Error on level that already exists") then

      mock_core_failure;
      level := new_log_level("my_bad_level", log_level_t'pos(verbose));
      check_core_failure(
        "Cannot create log level ""my_bad_level"" with level 15 already used by ""verbose"".");
      unmock_core_failure;

      level := new_log_level("my_level1", 1);
      mock_core_failure;
      level := new_log_level("my_level2", 1);
      check_core_failure(
        "Cannot create log level ""my_level2"" with level 1 already used by ""my_level1"".");
      unmock_core_failure;

    elsif run("Error on undefined level") then
      mock_core_failure;
      assert get_name(custom_level2) = "custom_level2";
      check_core_failure("Use of undefined level custom_level2.");
      unmock_core_failure;

    elsif run("Max name length") then
      level := new_log_level("a_long_log_level_name", 1);
      assert_equal(max_level_length, 21);
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
