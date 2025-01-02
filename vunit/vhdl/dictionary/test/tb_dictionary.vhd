-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.dictionary.all;
use std.textio.all;

entity tb_dictionary is
  generic (
    runner_cfg : string);
end entity tb_dictionary;

architecture test_fixture of tb_dictionary is
begin

  test_runner : process
    variable value : line;
    variable passed : boolean;
    constant empty_dict : frozen_dictionary_t := empty;
    constant test_dict : frozen_dictionary_t := "output path : c::\foo\bar, input path : c::\ying\yang, active python runner : true";
    constant corrupt_dict : frozen_dictionary_t := "output path : c::\foo\bar, input path, active python runner : true";
  begin

    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test that an empty frozen dictionary has zero length") then
        check(len(empty_dict) = 0, "An empty frozen directory should be of zero length (got " & natural'image(len(empty_dict)) & ").");

      elsif run("Test that a non-empty frozen dictionary has correct length") then
        check(len(test_dict) = 3, "Expected length of test dictionary to be 3 (got " & natural'image(len(test_dict)) & ").");

      elsif run("Test that the existence of a key can be queried") then
        check(has_key(test_dict, "input path"), "Should find ""input path"" in dictionary");
        check(has_key(test_dict, "  active python runner  "), "Should strip key before searching for it in the dictionary");
        check_false(has_key(test_dict, "input_path"), "Shouldn't find ""input_path"" in dictionary");

      elsif run("Test that getting a non-existing key from a frozen dictionary results in an assertion") then
        mock(dictionary_logger);
        write(value, get(empty_dict, "some_key"));
        check_only_log(dictionary_logger, "Key error! ""some_key"" wasn't found in """".", failure);
        unmock(dictionary_logger);

      elsif run("Test getting an existing key from a frozen dictionary") then
        passed := get(test_dict, "input path") = "c:\ying\yang";
        check(passed, "Expected ""c:\ying\yang"" when getting input path key from test dictionary (got """ & get(test_dict, "input path") & """).");
        passed := get(test_dict, "output path") = "c:\foo\bar";
        check(passed, "Expected ""c:\foo\bar"" when getting ""output path"" key from test dictionary (got """ & get(test_dict, "input path") & """).");
        passed := get(test_dict, " output path ") = "c:\foo\bar";
        check(passed, "Expected ""c:\foo\bar"" when getting "" output path "" key from test dictionary (got """ & get(test_dict, "input path") & """).");

      elsif run("Test that a corrupted directory results in an assertion") then
        mock(dictionary_logger);
        write(value, get(corrupt_dict, "input path"));
        check_only_log(dictionary_logger,
                       "Corrupt frozen dictionary item "" input path"" in ""output path : c::\foo\bar, input path, active python runner : true"".",
                       failure);
        unmock(dictionary_logger);

      elsif run("Test that get with default value returns value for existing key") then
        passed := get(test_dict, "input path", "banana") = "c:\ying\yang";
        check(passed, "Expected ""c:\ying\yang"" when getting input path key from test dictionary (got """ & get(test_dict, "input path", "banana") & """).");

      elsif run("Test that get with default value returns default value for non-existing key") then
        passed := get(test_dict, "meatballs", "falafel") = "falafel";
        check(passed, "Expected ""falafel"" when getting meatballs key from test dictionary (got """ & get(test_dict, "meatballs", "falafel") & """).");
      end if;
    end loop;

    reset_checker_stat;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 1 ns);
end test_fixture;
