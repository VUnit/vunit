-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.dict_pkg.all;

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.core_pkg.all;
use work.test_support_pkg.all;
use work.print_pkg.all;

entity tb_log is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_log is
begin
  main : process
    constant main_path : string := main'instance_name;

    procedure check_empty_log_file(constant file_name : in string) is
      file fptr : text;
      variable status : file_open_status;
    begin
      file_open(status, fptr, file_name, read_mode);
      assert status = open_ok report "Expected a file " & file_name severity failure;
      assert endfile(fptr) report "Expected " & file_name & " to be empty" severity FAILURE;
      file_close(fptr);
    end;

    procedure check_log_file (
      constant file_name : in string;
      constant entries   : in dict_t) is
      file fptr : text;
      variable l : line;
      variable status : file_open_status;
    begin
      file_open(status, fptr, file_name, read_mode);
      assert status = open_ok
        report "Failed opening " & file_name & " (" & file_open_status'image(status) & ")."
        severity failure;

      if status = open_ok then
        for i in 0 to num_keys(entries)-1 loop
          readline(fptr, l);
          assert l.all = get(entries, integer'image(i))
            report "(" & integer'image(i) & ") " & LF & "Got:" & LF & l.all & LF & "expected:" & LF & get(entries, integer'image(i))
            severity failure;
        end loop;
      end if;
    end;

    constant log_file_name : string := output_path(runner_cfg) & "my_log.csv";
    variable logger : logger_t := get_logger("logger");
    variable nested_logger : logger_t := get_logger("nested", parent => logger);
    variable other_logger : logger_t := get_logger("other");
    variable tmp_logger : logger_t;
    variable entries : dict_t := new_dict;
    variable entries2 : dict_t := new_dict;
    variable tmp : integer;
    file fptr : text;
    variable status : file_open_status;

    procedure perform_logging(logger : logger_t) is
    begin
      verbose(logger, "message 1");
      wait for 1 ns;
      debug(logger, "message 2");
      wait for 1 ns;
      info(logger, "message 3");
      wait for 1 ns;
      warning(logger, "message 4");
      wait for 1 ns;
      error(logger, "message 5");
      wait for 1 ns;
      failure(logger, "message 6");
      wait for 1 ns;
    end procedure;

    constant max_time_str : string := time'image(1 sec);
    constant time_padding  : string(max_time_str'range) := (others => ' ');
    impure function format_time(t : time) return string is
      constant time_str : string := time'image(t);
    begin
      return (1 to (max_time_str'length - time_str'length) => ' ') & time_str;
    end function;
  begin

    -- Check defaults before test runner setup
    assert_equal(get_log_count, 0);
    assert_equal(num_log_handlers(logger), 2);
    assert_true(get_log_handler(logger, 0) = display_handler);
    assert_true(get_log_handler(logger, 1) = file_handler);
    assert_true(get_log_handlers(logger) = (display_handler, file_handler));

    assert_true(get_enabled_log_levels(logger, display_handler) = (info, warning, error, failure));
    assert_true(get_enabled_log_levels(logger, file_handler) = (debug, info, warning, error, failure));

    test_runner_setup(runner, runner_cfg);
    set_log_level(file_handler, verbose);
    set_log_level(display_handler, verbose);

    if run("raw format") then
      set_format(display_handler, format => raw);
      init_log_handler(file_handler, file_name => log_file_name, format => raw);
      disable_stop;
      perform_logging(logger);
      set(entries, "0", "message 1");
      set(entries, "1", "message 2");
      set(entries, "2", "message 3");
      set(entries, "3", "message 4");
      set(entries, "4", "message 5");
      set(entries, "5", "message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("Can get file name") then
      init_log_handler(file_handler, file_name => log_file_name, format => raw);
      assert_equal(get_file_name(file_handler), log_file_name);
      assert_equal(get_file_name(display_handler), stdout_file_name);

    elsif run("Can print independent of logging") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);

      print("message 1", log_file_name);
      verbose(logger, "message 2");
      print("message 3", log_file_name);
      verbose(logger, "message 4");

      file_open(status, fptr, log_file_name, append_mode);
      assert status = open_ok
        report "Failed to open file " & log_file_name & " - " & file_open_status'image(status) severity failure;
      print("message 5", fptr);
      file_close(fptr);

      set(entries, "0", "message 1");
      set(entries, "1", "VERBOSE - message 2");
      set(entries, "2", "message 3");
      set(entries, "3", "VERBOSE - message 4");
      set(entries, "4", "message 5");
      check_log_file(log_file_name, entries);

      print("message 6", log_file_name, write_mode);
      set(entries2, "0", "message 6");
      check_log_file(log_file_name, entries2);

    elsif run("Can use 'instance_name") then
      tmp_logger := get_logger(tmp_logger'instance_name);
      assert_equal(get_name(tmp_logger), "tmp_logger");
      assert_equal(get_name(get_parent(tmp_logger)), "main");
      assert_equal(get_name(get_parent(get_parent(tmp_logger))), "tb_log(a)");
      assert_equal(get_full_name(tmp_logger), "tb_log(a):main:tmp_logger");

      assert_equal(get_full_name(get_parent(get_parent(tmp_logger))), "tb_log(a)");
      assert_true(get_logger("tb_log(a):main:tmp_logger") = tmp_logger);

      tmp_logger := get_logger(main_path);
      assert_true(main_path(main_path'right) = ':');
      assert_equal(get_name(tmp_logger), "main");
      assert_equal(get_name(get_parent(tmp_logger)), "tb_log(a)");
      assert_equal(get_full_name(tmp_logger), "tb_log(a):main");

      assert_equal(get_full_name(get_parent(tmp_logger)), "tb_log(a)");
      assert_true(get_logger("tb_log(a):main") = tmp_logger);

    elsif run("level format") then
      set_format(display_handler, format => level);
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      disable_stop;
      perform_logging(logger);
      set(entries, "0", "VERBOSE - message 1");
      set(entries, "1", "  DEBUG - message 2");
      set(entries, "2", "   INFO - message 3");
      set(entries, "3", "WARNING - message 4");
      set(entries, "4", "  ERROR - message 5");
      set(entries, "5", "FAILURE - message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("level format aligns multi line logs") then
      set_format(display_handler, format => level);
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      info(logger, "hello" & LF & "world" & LF & "    !");
      set(entries, "0", "   INFO - hello");
      set(entries, "1", "          world");
      set(entries, "2", "              !");
      check_log_file(log_file_name, entries);

    elsif run("csv format") then
      set_format(display_handler, format => csv);
      init_log_handler(file_handler, file_name => log_file_name, format => csv);
      disable_stop;
      wait for 3 ns;
      tmp := get_log_count;
      warning(nested_logger, "msg1");
      info(logger, "msg2", file_name => "file_name.vhd", line_num => 11);
      set(entries, "0", integer'image(tmp+0) & "," & time'image(3 ns) & ",WARNING,,,logger:nested,msg1");
      set(entries, "1", integer'image(tmp+1) & "," & time'image(3 ns) & ",INFO,file_name.vhd,11,logger,msg2");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("verbose format") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      disable_stop;
      perform_logging(logger);
      set(entries, "0", format_time(0 ns) & " - logger               - VERBOSE - message 1");
      set(entries, "1", format_time(1 ns) & " - logger               -   DEBUG - message 2");
      set(entries, "2", format_time(2 ns) & " - logger               -    INFO - message 3");
      set(entries, "3", format_time(3 ns) & " - logger               - WARNING - message 4");
      set(entries, "4", format_time(4 ns) & " - logger               -   ERROR - message 5");
      set(entries, "5", format_time(5 ns) & " - logger               - FAILURE - message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("verbose format with file and line numbers") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      disable_stop;
      info(logger, "message", file_name => "tb_log.vhd", line_num => 188);
      info(logger, "hello" & LF & "world", file_name => "tb_log.vhd", line_num => 189);
      set(entries, "0", format_time(0 ns) & " - logger               -    INFO - message (tb_log.vhd:188)");
      set(entries, "1", format_time(0 ns) & " - logger               -    INFO - hello (tb_log.vhd:189)");
      set(entries, "2", time_padding      & "                                    world");
      check_log_file(log_file_name, entries);

    elsif run("verbose format aligns multi line logs") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      info(logger, "hello" & LF & "world" & LF & "    !");
      set(entries, "0", format_time(0 ns) & " - logger               -    INFO - hello");
      set(entries, "1", time_padding      & "                                    world");
      set(entries, "2", time_padding      & "                                        !");
      check_log_file(log_file_name, entries);

    elsif run("hierarchical format") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      disable_stop;
      perform_logging(nested_logger);
      set(entries, "0", format_time(0 ns) & " - logger:nested        - VERBOSE - message 1");
      set(entries, "1", format_time(1 ns) & " - logger:nested        -   DEBUG - message 2");
      set(entries, "2", format_time(2 ns) & " - logger:nested        -    INFO - message 3");
      set(entries, "3", format_time(3 ns) & " - logger:nested        - WARNING - message 4");
      set(entries, "4", format_time(4 ns) & " - logger:nested        -   ERROR - message 5");
      set(entries, "5", format_time(5 ns) & " - logger:nested        - FAILURE - message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(nested_logger, error);
      reset_log_count(nested_logger, failure);

    elsif run("can log to default logger") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);

      disable_stop;
      debug("message 1");
      wait for 1 ns;
      verbose("message 2");
      wait for 1 ns;
      info("message 3");
      wait for 1 ns;
      warning("message 4");
      wait for 1 ns;
      error("message 5");
      wait for 1 ns;
      failure("message 6");

      set(entries, "0", "  DEBUG - message 1");
      set(entries, "1", "VERBOSE - message 2");
      set(entries, "2", "   INFO - message 3");
      set(entries, "3", "WARNING - message 4");
      set(entries, "4", "  ERROR - message 5");
      set(entries, "5", "FAILURE - message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(default_logger, error);
      reset_log_count(default_logger, failure);

    elsif run("can enable and disable handler") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      disable_stop;

      disable_all(file_handler);
      for log_level in verbose to failure loop
        assert_false(is_enabled(default_logger, file_handler, log_level));
        assert_false(is_enabled(logger, file_handler, log_level));
        assert_false(is_enabled(nested_logger, file_handler, log_level));
      end loop;

      perform_logging(logger);
      check_empty_log_file(log_file_name);

      set_log_level(file_handler, info);
      disable(file_handler, warning);

      enable_all(file_handler);
      for log_level in verbose to failure loop
        assert_true(is_enabled(default_logger, file_handler, log_level));
        assert_true(is_enabled(logger, file_handler, log_level));
        assert_true(is_enabled(nested_logger, file_handler, log_level));
      end loop;

      perform_logging(logger);
      set(entries, "0", "VERBOSE - message 1");
      set(entries, "1", "  DEBUG - message 2");
      set(entries, "2", "   INFO - message 3");
      set(entries, "3", "WARNING - message 4");
      set(entries, "4", "  ERROR - message 5");
      set(entries, "5", "FAILURE - message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("can set log level") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      set_log_level(file_handler, warning);
      disable_stop;
      perform_logging(logger);
      set(entries, "0", "WARNING - message 4");
      set(entries, "1", "  ERROR - message 5");
      set(entries, "2", "FAILURE - message 6");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("can set disable individual levels") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      disable(file_handler, (verbose, debug, info, error, failure));
      disable_stop;
      perform_logging(logger);
      set(entries, "0", "WARNING - message 4");
      check_log_file(log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("log level also set for nested loggers") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      set_log_level(logger, file_handler, failure);
      disable_stop;
      info(logger, "message 1");
      info(nested_logger, "message 2");
      info("message 3");
      set(entries, "0", "   INFO - message 3");
      check_log_file(log_file_name, entries);

    elsif run("can enable and disable source") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      disable_all(logger, file_handler);

      for log_level in verbose to failure loop
        assert_true(is_enabled(default_logger, file_handler, log_level));
        assert_false(is_enabled(logger, file_handler, log_level));
        assert_false(is_enabled(nested_logger, file_handler, log_level));
      end loop;

      info(logger, "message");
      info(nested_logger, "message");
      info("message");
      set(entries, "0", "   INFO - message");
      check_log_file(log_file_name, entries);

      init_log_handler(file_handler, file_name => log_file_name, format => level);
      set_log_level(logger, file_handler, info);
      disable(logger, file_handler, warning);
      enable_all(logger, file_handler);
      for log_level in verbose to failure loop
        assert_true(is_enabled(default_logger, file_handler, log_level));
        assert_true(is_enabled(logger, file_handler, log_level));
        assert_true(is_enabled(nested_logger, file_handler, log_level));
      end loop;

      info(logger, "message 1");
      info(nested_logger, "message 2");
      info("message 3");
      set(entries, "0", "   INFO - message 1");
      set(entries, "1", "   INFO - message 2");
      set(entries, "2", "   INFO - message 3");
      check_log_file(log_file_name, entries);

    elsif run("mock and unmock") then
      mock(logger);
      unmock(logger);

    elsif run("mock check_only_log") then
      mock(logger);
      warning(logger, "message");
      check_only_log(logger, "message", warning, 0 ns);
      unmock(logger);

    elsif run("mocked logger does not stop simulation") then
      mock(logger);
      failure(logger, "message");
      check_only_log(logger, "message", failure, 0 ns);
      unmock(logger);

    elsif run("mocked logger is always enabled") then
      assert_true(is_enabled(logger, failure));

      disable_all(logger, display_handler);
      disable_all(logger, file_handler);
      assert_false(is_enabled(logger, failure));

      mock(logger);
      assert_true(is_enabled(logger, failure));

      unmock(logger);
      assert_false(is_enabled(logger, failure));

    elsif run("mock check_log") then
      mock(logger);
      warning(logger, "message");
      wait for 1 ns;
      info(logger, "another message");
      check_log(logger, "message", warning, 0 ns);
      check_log(logger, "another message", info, 1 ns);
      unmock(logger);

    elsif run("unmock with unchecked log fails") then
      mock(logger);
      warning(logger, "message");

      mock_core_failure;
      unmock(logger);
      check_and_unmock_core_failure;

    elsif run("check_only_log when no log fails") then
      mock(logger);
      mock_core_failure;
      check_only_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log when wrong level fails") then
      mock(logger);
      debug(logger, "message");
      mock_core_failure;
      check_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log when wrong message fails") then
      mock(logger);
      warning(logger, "another message");
      mock_core_failure;
      check_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log when wrong time fails") then
      mock(logger);
      wait for 1 ns;
      warning(logger, "message");
      mock_core_failure;
      check_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("log below stop level") then
      set_stop_level(warning);
      info(logger, "message");
      set_stop_level(logger, warning);
      info(logger, "message");

    elsif run("log above stop level fails") then
      set_stop_level(warning);
      mock_core_failure;
      warning("message");
      check_and_unmock_core_failure;
      reset_log_count(default_logger);

      set_stop_level(logger, warning);
      mock_core_failure;
      warning(logger, "message");
      check_and_unmock_core_failure;
      reset_log_count(logger);

    elsif run("log above stop count fails") then
      set_stop_count(logger, failure, 2);
      -- Should not fail
      failure(logger, "message");
      mock_core_failure;
      failure(logger, "message");
      check_and_unmock_core_failure;
      reset_log_count(logger);

      set_stop_count(failure, 2);
      -- Should not fail
      failure("message");
      mock_core_failure;
      failure("message");
      check_and_unmock_core_failure;
      reset_log_count(default_logger);

    elsif run("disable_stop pass all levels") then
      disable_stop;
      failure("failure");
      failure(logger, "failure");
      reset_log_count(default_logger);
      reset_log_count(logger);

    elsif run("Get logger") then
      tmp_logger := get_logger("logger:child");
      assert_equal(get_name(tmp_logger), "child");
      assert_equal(get_full_name(tmp_logger), "logger:child");

      tmp_logger := get_logger("logger:child:grandchild");
      assert_equal(get_name(tmp_logger), "grandchild");
      assert_equal(get_full_name(tmp_logger), "logger:child:grandchild");

      tmp_logger := get_logger("default");
      assert_true(tmp_logger = default_logger);

      tmp_logger := get_logger("logger:nested");
      assert_true(tmp_logger = nested_logger);

      tmp_logger := get_logger("nested", parent => logger);
      assert_true(tmp_logger = nested_logger);

    elsif run("Create hierarchical logger") then
      tmp_logger := get_logger("logger:child");
      assert_false(tmp_logger = null_logger, "logger not null");
      assert_equal(get_name(tmp_logger), "child", "nested logger name");
      assert_true(get_parent(tmp_logger) = logger, "parent logger");

    elsif run("Log counts") then
      disable_stop;
      tmp := 0;

      for lvl in verbose to failure loop
        if is_valid(lvl) then
          log(logger, "msg", lvl);
          assert_equal(get_log_count(logger, lvl), 1);
        end if;
      end loop;

      reset_log_count(logger);

      for lvl in verbose to failure loop
        if is_valid(lvl) then
          assert_equal(get_log_count(logger, lvl), 0);
        end if;
      end loop;

      for lvl in verbose to failure loop
        if is_valid(lvl) then
          assert_equal(get_log_count(logger, lvl), 0);
          log(logger, "msg", lvl);
          tmp := tmp + 1;

          for lvl2 in verbose to failure loop
            if is_valid(lvl2) then
              assert_equal(get_mock_log_count(logger, lvl2), 0, "no mock log count");

              if lvl2 <= lvl then
                assert_equal(get_log_count(logger, lvl2), 1);
              else
                assert_equal(get_log_count(logger, lvl2), 0);
              end if;
            end if;
          end loop;

          assert_equal(get_log_count(logger), tmp, "total");
        end if;
      end loop;

      for lvl in verbose to failure loop
        if is_valid(lvl) then
          reset_log_count(logger, lvl);
          assert_equal(get_log_count(logger, lvl), 0, "log count is reset");
          tmp := tmp - 1;
          assert_equal(get_log_count(logger), tmp, "total");

          for lvl2 in verbose to failure loop
            if is_valid(lvl2) then
              if lvl2 > lvl then
                assert_equal(get_log_count(logger, lvl2), 1);
              else
                assert_equal(get_log_count(logger, lvl2), 0);
              end if;
            end if;
          end loop;
        end if;
      end loop;

    elsif run("Test global log count") then
      tmp := get_log_count;
      info(logger, "msg");
      assert_equal(get_log_count - tmp, 1);

      set_log_level(file_handler, failure);
      set_log_level(display_handler, failure);
      verbose(logger, "msg");
      assert_equal(get_log_count - tmp, 2);

    elsif run("Does not log counts when mocked") then
      mock(logger);

      tmp := 0;
      for lvl in verbose to failure loop
        if is_valid(lvl) then
          assert_equal(get_mock_log_count(logger, lvl), 0);
          log(logger, "message", lvl);
          assert_equal(get_mock_log_count(logger, lvl), 1);
          assert_equal(get_log_count(logger, lvl), 0);
          check_only_log(logger, "message", lvl);
          tmp := tmp + 1;
        end if;
      end loop;

      assert_equal(get_mock_log_count(logger), tmp);
      assert_equal(get_log_count(logger), 0);

      unmock(logger);

      assert_equal(get_mock_log_count(logger), 0);
      assert_equal(get_log_count(logger), 0);

      for lvl in verbose to failure loop
        if is_valid(lvl) then
          assert_equal(get_log_count(logger, lvl), 0);
          assert_equal(get_mock_log_count(logger, lvl), 0,
                       "reset mock log count after unmock");
        end if;
      end loop;

    elsif run("Test logger name validation") then
      tmp_logger := get_logger("foo:bar");
      assert_equal(get_name(get_logger("foo")), "foo");

      mock_core_failure;
      tmp_logger := get_logger("foo,bar");
      check_core_failure("Invalid logger name ""foo,bar""");

      tmp_logger := get_logger("parent:foo,bar");
      check_core_failure("Invalid logger name ""parent:foo,bar""");

      tmp_logger := get_logger("");
      check_core_failure("Invalid logger name """"");

      tmp_logger := get_logger(":");
      check_core_failure("Invalid logger name """"");

      unmock_core_failure;

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
