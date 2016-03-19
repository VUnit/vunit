-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_base_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.dictionary.all;
use std.textio.all;

entity tb_dictionary is
  generic (
    runner_cfg : string;
    output_path : string);
end entity tb_dictionary;

architecture test_fixture of tb_dictionary is
begin
  test_runner : process
    variable stop_level : log_level_t := failure;
    variable value : line;
    variable log_call_count : natural;
    variable args : log_call_args_t;
    variable c : checker_t;
    variable stat : checker_stat_t;
    variable passed : boolean;
    constant empty_dict : frozen_dictionary_t := empty_c;
    constant test_dict : frozen_dictionary_t := "output path : c::\foo\bar, input path : c::\ying\yang, active python runner : true";
    constant corrupt_dict : frozen_dictionary_t := "output path : c::\foo\bar, input path, active python runner : true";
  begin
    checker_init(c, default_src => "Test Runner", display_format => verbose, file_name => output_path & "error.csv");
    if has_key(runner_cfg, "active python runner") then
      if get(runner_cfg, "active python runner") = "true" then
        checker_init(c, default_src => "Test Runner", display_format => verbose, stop_level => error, file_name => output_path & "error.csv");
      end if;
    end if;
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test that an empty frozen dictionary has zero length") then
        check(c, len(empty_dict) = 0, "An empty frozen directory should be of zero length (got " & natural'image(len(empty_dict)) & ").");
      elsif run("Test that a non-empty frozen dictionary has correct length") then
        check(c, len(test_dict) = 3, "Expected length of test dictionary to be 3 (got " & natural'image(len(test_dict)) & ").");
      elsif run("Test that the existence of a key can be queried") then
        check(c, has_key(test_dict, "input path"), "Should find ""input path"" in dictionary");
        check(c, has_key(test_dict, "  active python runner  "), "Should strip key before searching for it in the dictionary");
        check_false(c, has_key(test_dict, "input_path"), "Shouldn't find ""input_path"" in dictionary");
      elsif run("Test that getting a non-existing key from a frozen dictionary results in an assertion") then
        log_call_count := get_log_call_count;
        write(value, get(empty_dict, "some_key"));
        check(c, get_log_call_count = log_call_count + 1, "Expected error log call at this point.");
        get_log_call_args(args);
        check(c, args.level = failure, "Expected the error call to be on failure level.");
      elsif run("Test getting an existing key from a frozen dictionary") then
        passed := get(test_dict, "input path") = "c:\ying\yang";
        check(c, passed, "Expected ""c:\ying\yang"" when getting input path key from test dictionary (got """ & get(test_dict, "input path") & """).");
        passed := get(test_dict, "output path") = "c:\foo\bar";
        check(c, passed, "Expected ""c:\foo\bar"" when getting ""output path"" key from test dictionary (got """ & get(test_dict, "input path") & """).");
        passed := get(test_dict, " output path ") = "c:\foo\bar";
        check(c, passed, "Expected ""c:\foo\bar"" when getting "" output path "" key from test dictionary (got """ & get(test_dict, "input path") & """).");
      elsif run("Test that a corrupted directory results in an assertion") then
        log_call_count := get_log_call_count;
        write(value, get(corrupt_dict, "input path"));
        check(c, get_log_call_count = log_call_count + 1, "Expected error log call at this point.");
        get_log_call_args(args);
        check(c, args.level = failure, "Expected the error call to be on failure level.");
      end if;
    end loop;
    reset_checker_stat;
    get_checker_stat(c, stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 1 ns);
end test_fixture;
