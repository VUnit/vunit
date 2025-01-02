-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
use work.id_pkg.all;

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

    procedure flush_file_handler(file_handler : log_handler_t) is
    begin
      -- Dummy init to flush file handler
      init_log_handler(file_handler,
                       file_name => get_file_name(file_handler) & ".dummy",
                       format => raw);
    end;

    procedure check_file(file_name : string;
                         entries   : dict_t) is
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
          assert l.all = get_string(entries, integer'image(i))
            report "(" & integer'image(i) & ") " & LF & "Got:" & LF & l.all & LF & "expected:" & LF & get_string(entries, integer'image(i))
            severity failure;
        end loop;
      end if;
    end;

    procedure check_log_file (file_handler : log_handler_t;
                              file_name : string;
                              entries   : dict_t) is
    begin
      assert get_file_name(file_handler) = file_name report "file name mismatch";
      flush_file_handler(file_handler);
      check_file(file_name, entries);
    end;

    constant log_file_name : string := output_path(runner_cfg) & "my_log.csv";
    constant print_file_name : string := output_path(runner_cfg) & "print.csv";
    variable logger : logger_t := get_logger("logger");
    variable nested_logger : logger_t := get_logger("nested", parent => logger);
    variable tmp_logger : logger_t;
    variable entries : dict_t := new_dict;
    variable entries2 : dict_t := new_dict;
    variable tmp : integer;
    file fptr : text;
    variable status : file_open_status;

    procedure perform_logging(logger : logger_t) is
    begin
      trace(logger, "message 1");
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

    impure function format_time(time_str : string) return string is
    begin
      return (1 to (max_time_str'length - time_str'length) => ' ') & time_str;
    end function;

    impure function format_time(t : time) return string is
    begin
      return format_time(time'image(t));
    end function;

    variable file_handler : log_handler_t := new_log_handler(log_file_name,
                                                             format => verbose,
                                                             use_color => false);
    variable file_handlers : log_handler_vec_t(0 to 63);
    variable loggers : logger_vec_t(file_handlers'range);
  begin

    -- Check defaults before test runner setup
    assert_equal(get_log_count, 0);
    assert_equal(num_log_handlers(logger), 1);
    assert_true(get_log_handler(logger, 0) = display_handler);
    assert_true(get_log_handlers(logger) = (0 => display_handler));
    assert_true(get_visible_log_levels(logger, display_handler) = (info, warning, error, failure));

    -- Check default stop count
    for log_level in legal_log_level_t'low to legal_log_level_t'high loop
      case log_level is
        when error|failure =>
          assert_equal(get_stop_count(root_logger, log_level), 1);
        when others =>
          assert_equal(get_stop_count(root_logger, log_level), integer'high);
      end case;
    end loop;

    test_runner_setup(runner, runner_cfg);
    set_log_handlers(root_logger, (display_handler, file_handler));
    show_all(root_logger, file_handler);
    show_all(root_logger, display_handler);

    if run("raw format") then
      set_format(display_handler, format => raw);
      init_log_handler(file_handler, file_name => log_file_name, format => raw);
      disable_stop(logger, error);
      disable_stop(logger, failure);
      perform_logging(logger);
      set_string(entries, "0", "message 1");
      set_string(entries, "1", "message 2");
      set_string(entries, "2", "message 3");
      set_string(entries, "3", "message 4");
      set_string(entries, "4", "message 5");
      set_string(entries, "5", "message 6");

      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("Can get file name") then
      init_log_handler(file_handler, file_name => log_file_name, format => raw);
      assert_equal(get_file_name(file_handler), log_file_name);
      assert_equal(get_file_name(display_handler), stdout_file_name);

    elsif run("Can print independent of logging") then
      print("message 1", print_file_name);
      print("message 2", print_file_name);

      file_open(status, fptr, print_file_name, append_mode);
      assert status = open_ok
        report "Failed to open file " & print_file_name & " - " & file_open_status'image(status) severity failure;
      print("message 3", fptr);
      file_close(fptr);

      set_string(entries, "0", "message 1");
      set_string(entries, "1", "message 2");
      set_string(entries, "2", "message 3");
      check_file(print_file_name, entries);

      print("message 6", print_file_name, write_mode);
      set_string(entries2, "0", "message 6");
      check_file(print_file_name, entries2);

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
      disable_stop(logger, error);
      disable_stop(logger, failure);
      perform_logging(logger);
      set_string(entries, "0", "  TRACE - message 1");
      set_string(entries, "1", "  DEBUG - message 2");
      set_string(entries, "2", "   INFO - message 3");
      set_string(entries, "3", "WARNING - message 4");
      set_string(entries, "4", "  ERROR - message 5");
      set_string(entries, "5", "FAILURE - message 6");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("level format aligns multi line logs") then
      set_format(display_handler, format => level);
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      info(logger, "hello" & LF & "world" & LF & "    !");
      set_string(entries, "0", "   INFO - hello");
      set_string(entries, "1", "          world");
      set_string(entries, "2", "              !");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("csv format") then
      set_format(display_handler, format => csv);
      init_log_handler(file_handler, file_name => log_file_name, format => csv);

      wait for 3 ns;
      tmp := get_log_count;
      warning(nested_logger, "msg1");
      info(logger, "msg2", file_name => "file_name.vhd", line_num => 11);
      set_string(entries, "0", integer'image(tmp+0) & "," & time'image(3 ns) & ",WARNING,,,logger:nested,msg1");
      set_string(entries, "1", integer'image(tmp+1) & "," & time'image(3 ns) & ",INFO,file_name.vhd,11,logger,msg2");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("verbose format") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      disable_stop(logger, error);
      disable_stop(logger, failure);
      perform_logging(logger);
      set_string(entries, "0", format_time(0 ns) & " - logger               -   TRACE - message 1");
      set_string(entries, "1", format_time(1 ns) & " - logger               -   DEBUG - message 2");
      set_string(entries, "2", format_time(2 ns) & " - logger               -    INFO - message 3");
      set_string(entries, "3", format_time(3 ns) & " - logger               - WARNING - message 4");
      set_string(entries, "4", format_time(4 ns) & " - logger               -   ERROR - message 5");
      set_string(entries, "5", format_time(5 ns) & " - logger               - FAILURE - message 6");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("verbose format with file and line numbers") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      info(logger, "message", file_name => "tb_log.vhd", line_num => 188);
      info(logger, "hello" & LF & "world", file_name => "tb_log.vhd", line_num => 189);
      set_string(entries, "0", format_time(0 ns) & " - logger               -    INFO - message (tb_log.vhd:188)");
      set_string(entries, "1", format_time(0 ns) & " - logger               -    INFO - hello (tb_log.vhd:189)");
      set_string(entries, "2", time_padding      & "                                    world");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("verbose format aligns multi line logs") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      info(logger, "hello" & LF & "world" & LF & "    !");
      set_string(entries, "0", format_time(0 ns) & " - logger               -    INFO - hello");
      set_string(entries, "1", time_padding      & "                                    world");
      set_string(entries, "2", time_padding      & "                                        !");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("verbose format with auto unit and fix number of decimals") then
      set_format(display_handler, format => verbose, log_time_unit => auto_time_unit, n_log_time_decimals => 2);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose,
        log_time_unit => auto_time_unit, n_log_time_decimals => 2
      );
      wait for 123456 ps;
      info(logger, "message");
      set_string(entries, "0", format_time("123.45 ns") & " - logger               -    INFO - message");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("verbose format with custom unit and full resolution") then
      set_format(display_handler, format => verbose, log_time_unit => us, n_log_time_decimals => 8);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose,
        log_time_unit => us, n_log_time_decimals => 8
      );
      wait for 12345 ps;
      info(logger, "message");
      set_string(entries, "0", format_time("0.01234500 us") & " - logger               -    INFO - message");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("hierarchical format") then
      set_format(display_handler, format => verbose);
      init_log_handler(file_handler, file_name => log_file_name, format => verbose);
      disable_stop(nested_logger, error);
      disable_stop(nested_logger, failure);
      perform_logging(nested_logger);
      set_string(entries, "0", format_time(0 ns) & " - logger:nested        -   TRACE - message 1");
      set_string(entries, "1", format_time(1 ns) & " - logger:nested        -   DEBUG - message 2");
      set_string(entries, "2", format_time(2 ns) & " - logger:nested        -    INFO - message 3");
      set_string(entries, "3", format_time(3 ns) & " - logger:nested        - WARNING - message 4");
      set_string(entries, "4", format_time(4 ns) & " - logger:nested        -   ERROR - message 5");
      set_string(entries, "5", format_time(5 ns) & " - logger:nested        - FAILURE - message 6");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(nested_logger, error);
      reset_log_count(nested_logger, failure);

    elsif run("can log to default logger") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);

      disable_stop(default_logger, error);
      disable_stop(default_logger, failure);
      debug("message 1");
      wait for 1 ns;
      trace("message 2");
      wait for 1 ns;
      info("message 3");
      wait for 1 ns;
      warning("message 4");
      wait for 1 ns;
      error("message 5");
      wait for 1 ns;
      failure("message 6");

      set_string(entries, "0", "  DEBUG - message 1");
      set_string(entries, "1", "  TRACE - message 2");
      set_string(entries, "2", "   INFO - message 3");
      set_string(entries, "3", "WARNING - message 4");
      set_string(entries, "4", "  ERROR - message 5");
      set_string(entries, "5", "FAILURE - message 6");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(default_logger, error);
      reset_log_count(default_logger, failure);

    elsif run("can show and hide from handler") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      disable_stop(root_logger, error);
      disable_stop(root_logger, failure);

      hide_all(file_handler);
      for log_level in trace to failure loop
        assert_false(is_visible(default_logger, file_handler, log_level));
        assert_false(is_visible(logger, file_handler, log_level));
        assert_false(is_visible(nested_logger, file_handler, log_level));
      end loop;

      perform_logging(logger);
      check_empty_log_file(log_file_name);

      show_all(file_handler);
      for log_level in trace to failure loop
        assert_true(is_visible(default_logger, file_handler, log_level));
        assert_true(is_visible(logger, file_handler, log_level));
        assert_true(is_visible(nested_logger, file_handler, log_level));
      end loop;

      perform_logging(logger);
      set_string(entries, "0", "  TRACE - message 1");
      set_string(entries, "1", "  DEBUG - message 2");
      set_string(entries, "2", "   INFO - message 3");
      set_string(entries, "3", "WARNING - message 4");
      set_string(entries, "4", "  ERROR - message 5");
      set_string(entries, "5", "FAILURE - message 6");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("can show individual levels") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      hide_all(file_handler);
      show(file_handler, (warning, error, failure));
      disable_stop(root_logger, error);
      disable_stop(root_logger, failure);
      perform_logging(logger);
      set_string(entries, "0", "WARNING - message 4");
      set_string(entries, "1", "  ERROR - message 5");
      set_string(entries, "2", "FAILURE - message 6");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("can hide individual levels") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      hide(file_handler, (trace, debug, info, error, failure));
      disable_stop(root_logger, error);
      disable_stop(root_logger, failure);
      perform_logging(logger);
      set_string(entries, "0", "WARNING - message 4");
      check_log_file(file_handler, log_file_name, entries);
      reset_log_count(logger, error);
      reset_log_count(logger, failure);

    elsif run("visibility also set for nested loggers") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      hide_all(logger, file_handler);
      show(logger, file_handler, failure);
      info(logger, "message 1");
      info(nested_logger, "message 2");
      info("message 3");
      set_string(entries, "0", "   INFO - message 3");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("can show and hide source") then
      init_log_handler(file_handler, file_name => log_file_name, format => level);
      hide_all(logger, file_handler);

      for log_level in trace to failure loop
        assert_true(is_visible(default_logger, file_handler, log_level));
        assert_false(is_visible(logger, file_handler, log_level));
        assert_false(is_visible(nested_logger, file_handler, log_level));
      end loop;

      info(logger, "message");
      info(nested_logger, "message");
      info("message");
      set_string(entries, "0", "   INFO - message");
      check_log_file(file_handler, log_file_name, entries);

      init_log_handler(file_handler, file_name => log_file_name, format => level);
      show_all(logger, file_handler);
      for log_level in trace to failure loop
        assert_true(is_visible(default_logger, file_handler, log_level));
        assert_true(is_visible(logger, file_handler, log_level));
        assert_true(is_visible(nested_logger, file_handler, log_level));
      end loop;

      info(logger, "message 1");
      info(nested_logger, "message 2");
      info("message 3");
      set_string(entries, "0", "   INFO - message 1");
      set_string(entries, "1", "   INFO - message 2");
      set_string(entries, "2", "   INFO - message 3");
      check_log_file(file_handler, log_file_name, entries);

    elsif run("mock and unmock") then
      mock(logger);
      unmock(logger);

    elsif run("mock check_only_log") then
      mock(logger);
      warning(logger, "message");
      check_only_log(logger, "message", warning, 0 ns);
      unmock(logger);

    elsif run("mock individual levels") then
      mock(logger, error);

      warning(logger, "message");
      assert_equal(mock_queue_length, 0);
      check_no_log;

      error(logger, "message");
      assert_equal(mock_queue_length, 1);
      check_only_log(logger, "message", error, 0 ns);

      unmock(logger);

    elsif run("mock_queue_length") then
      mock(logger);
      assert_equal(mock_queue_length, 0);
      warning(logger, "message");
      assert_equal(mock_queue_length, 1);
      warning(logger, "message2");
      assert_equal(mock_queue_length, 2);
      check_log(logger, "message", warning, 0 ns);
      assert_equal(mock_queue_length, 1);
      check_only_log(logger, "message2", warning, 0 ns);
      assert_equal(mock_queue_length, 0);
      unmock(logger);

    elsif run("mocked logger does not stop simulation") then
      mock(logger);
      failure(logger, "message");
      check_only_log(logger, "message", failure, 0 ns);
      unmock(logger);

    elsif run("mocked logger is always visible") then
      assert_true(is_visible(logger, failure));

      hide_all(logger, display_handler);
      hide_all(logger, file_handler);
      assert_false(is_visible(logger, failure));

      mock(logger);
      assert_true(is_visible(logger, failure));

      unmock(logger);
      assert_false(is_visible(logger, failure));

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

    elsif run("check_only_log with no log fails") then
      mock(logger);
      mock_core_failure;
      check_only_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log with wrong level fails") then
      mock(logger);
      debug(logger, "message");
      mock_core_failure;
      check_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log with wrong message fails") then
      mock(logger);
      warning(logger, "another message");
      mock_core_failure;
      check_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log with wrong time fails") then
      mock(logger);
      wait for 1 ns;
      warning(logger, "message");
      mock_core_failure;
      check_log(logger, "message", warning, 0 ns);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("check_log with wrong logger fails") then
      mock(logger);
      failure(logger, "message");
      mock_core_failure;
      check_only_log(default_logger, "message", failure);
      check_and_unmock_core_failure;
      unmock(logger);

    elsif run("log above stop count fails") then
      set_stop_count(logger, failure, 2);
      -- Should not fail
      failure(logger, "message");
      mock_core_failure;
      failure(logger, "message");
      check_and_unmock_core_failure;
      reset_log_count(logger);

      set_stop_count(root_logger, failure, 2);
      -- Should not fail
      failure("message");
      mock_core_failure;
      failure("message");
      check_and_unmock_core_failure;
      reset_log_count(default_logger);

    elsif run("unset stop count on root logger fails") then
      unset_stop_count(root_logger, warning);
      mock_core_failure;
      warning("failure");
      check_and_unmock_core_failure("Stop condition not set on root_logger");

    elsif run("set_stop_level") then
      set_stop_level(warning);
      assert_equal(get_stop_count(root_logger, warning), 1);
      assert_equal(get_stop_count(root_logger, error), 1);
      assert_equal(get_stop_count(root_logger, failure), 1);

      set_stop_level(error);
      assert_equal(get_stop_count(root_logger, warning), integer'high);
      assert_equal(get_stop_count(root_logger, error), 1);
      assert_equal(get_stop_count(root_logger, failure), 1);

      set_stop_level(failure);
      assert_equal(get_stop_count(root_logger, warning), integer'high);
      assert_equal(get_stop_count(root_logger, error), integer'high);
      assert_equal(get_stop_count(root_logger, failure), 1);

      -- Sets others to infinite
      set_stop_count(root_logger, info, 1);
      set_stop_level(failure);
      assert_equal(get_stop_count(root_logger, info), integer'high);

    elsif run("set_stop_level clears subtree") then
      set_stop_count(get_logger("parent:my_logger"), error, 1);
      set_stop_level(get_logger("parent"), failure);
      assert_false(has_stop_count(get_logger("parent:my_logger"), error));

    elsif run("new logger has unset stop counts") then
      tmp_logger := get_logger("new_logger");

      for log_level in legal_log_level_t'low to legal_log_level_t'high loop
        assert_false(has_stop_count(tmp_logger, log_level));
      end loop;

    elsif run("Get logger by name") then
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

    elsif run("Get logger by id") then
      tmp_logger := get_logger(get_id("logger:child"));
      assert_equal(get_name(tmp_logger), "child");
      assert_equal(get_full_name(tmp_logger), "logger:child");

      tmp_logger := get_logger(get_id("logger:child:grandchild"));
      assert_equal(get_name(tmp_logger), "grandchild");
      assert_equal(get_full_name(tmp_logger), "logger:child:grandchild");

      tmp_logger := get_logger(get_id("default"));
      assert_true(tmp_logger = default_logger);

      tmp_logger := get_logger(get_id("logger:nested"));
      assert_true(tmp_logger = nested_logger);

      tmp_logger := get_logger(get_id("nested", parent => get_id(logger)));
      assert_true(tmp_logger = nested_logger);

    elsif run("Test has_logger") then
      tmp_logger := get_logger("parent:child");
      assert_true(has_logger(get_id("parent:child")));
      assert_true(has_logger(get_id("parent")));

      assert_false(has_logger(root_id));
      assert_false(has_logger(get_id("id")));
      assert_false(has_logger(get_id("parent:child2")));
      assert_false(has_logger(get_id("parent:child:grandchild")));

    elsif run("Create hierarchical logger") then
      tmp_logger := get_logger("logger:child");
      assert_false(tmp_logger = null_logger, "logger not null");
      assert_equal(get_name(tmp_logger), "child", "nested logger name");
      assert_true(get_parent(tmp_logger) = logger, "parent logger");

    elsif run("Log counts") then
      disable_stop(root_logger, error);
      disable_stop(root_logger, failure);
      tmp := 0;

      for lvl in trace to failure loop
        if is_valid(lvl) then
          log(logger, "msg", lvl);
          assert_equal(get_log_count(logger, lvl), 1);
        end if;
      end loop;

      reset_log_count(logger);

      for lvl in trace to failure loop
        if is_valid(lvl) then
          assert_equal(get_log_count(logger, lvl), 0);
        end if;
      end loop;

      for lvl in trace to failure loop
        if is_valid(lvl) then
          assert_equal(get_log_count(logger, lvl), 0);
          log(logger, "msg", lvl);
          tmp := tmp + 1;

          for lvl2 in trace to failure loop
            if is_valid(lvl2) then
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

      for lvl in trace to failure loop
        if is_valid(lvl) then
          reset_log_count(logger, lvl);
          assert_equal(get_log_count(logger, lvl), 0, "log count is reset");
          tmp := tmp - 1;
          assert_equal(get_log_count(logger), tmp, "total");

          for lvl2 in trace to failure loop
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

      trace(logger, "msg");
      assert_equal(get_log_count - tmp, 2);

    elsif run("Does not log counts when mocked") then
      mock(logger);

      tmp := 0;
      for lvl in trace to failure loop
        if is_valid(lvl) then
          log(logger, "message", lvl);
          assert_equal(get_log_count(logger, lvl), 0);
          check_only_log(logger, "message", lvl);
          tmp := tmp + 1;
        end if;
      end loop;

      assert_equal(get_log_count(logger), 0);

      unmock(logger);

      assert_equal(get_log_count(logger), 0);

      for lvl in trace to failure loop
        if is_valid(lvl) then
          assert_equal(get_log_count(logger, lvl), 0);
        end if;
      end loop;

    elsif run("Test logger name validation") then
      tmp_logger := get_logger("foo:bar");
      assert_equal(get_name(get_logger("foo")), "foo");

      mock_core_failure;
      tmp_logger := get_logger("foo,bar");
      check_core_failure("Invalid ID name ""foo,bar""");

      tmp_logger := get_logger("parent:foo,bar");
      check_core_failure("Invalid ID name ""parent:foo,bar""");

      tmp_logger := get_logger("par,ent:foo");
      check_core_failure("Invalid ID name ""par,ent""");

      tmp_logger := get_logger("");
      check_core_failure("Invalid ID name """"");

      tmp_logger := get_logger(":");
      check_core_failure("Invalid ID name """"");

      unmock_core_failure;

    elsif run("Test final log check fails for errors") then
      disable_stop(error);
      error(get_logger("parent:my_logger"), "message");
      mock_core_failure;
      final_log_check;
      check_and_unmock_core_failure;

      reset_log_count(get_logger("parent:my_logger"), error);

    elsif run("Test final log check fails for failures") then
      disable_stop(failure);
      failure(get_logger("parent:my_logger"), "message");
      failure(get_logger("parent:my_logger"), "message");
      mock_core_failure;
      final_log_check;
      check_and_unmock_core_failure;

      reset_log_count(get_logger("parent:my_logger"), failure);

    elsif run("Test final log check fails for unmocked logger") then
      mock(get_logger("parent:my_logger"), failure);
      mock_core_failure;
      final_log_check;
      check_and_unmock_core_failure;

      unmock(get_logger("parent:my_logger"));

    elsif run("Test final log check fails for disabled error") then
      disable(get_logger("parent:my_logger"), error);
      error(get_logger("parent:my_logger"), "message");
      mock_core_failure;
      final_log_check;
      check_and_unmock_core_failure;

      reset_log_count(get_logger("parent:my_logger"), error);

    elsif run("Test final log check fails for disabled failure") then
      disable(get_logger("parent:my_logger"), failure);
      failure(get_logger("parent:my_logger"), "message");
      mock_core_failure;
      final_log_check;
      check_and_unmock_core_failure;

      reset_log_count(get_logger("parent:my_logger"), failure);

    elsif run("Test final log check can allow disabled errors") then
      disable(get_logger("parent:my_logger"), error);
      error(get_logger("parent:my_logger"), "message");
      final_log_check(allow_disabled_errors => true);
      reset_log_count(get_logger("parent:my_logger"), error);

    elsif run("Test final log check can allow disabled failures") then
      disable(get_logger("parent:my_logger"), failure);
      failure(get_logger("parent:my_logger"), "message");
      final_log_check(allow_disabled_failures => true);
      reset_log_count(get_logger("parent:my_logger"), failure);

    elsif run("Test final log check optionally fails for warnings") then
      warning(get_logger("parent:my_logger"), "message");
      final_log_check; -- Does not fail

      mock_core_failure;
      final_log_check(fail_on_warning => true);
      check_and_unmock_core_failure;

      -- Does not fail for disabled warnings
      disable(get_logger("parent:my_logger"), warning);
      final_log_check(fail_on_warning => true);

    elsif run("Test conditional logs") then
      mock(logger);

      -- Warning
      warning_if(logger, True, "message");
      check_only_log(logger, "message", warning);

      warning_if(logger, False, "message");
      check_no_log;

      -- Error
      error_if(logger, True, "message");
      check_only_log(logger, "message", error);

      error_if(logger, False, "message");
      check_no_log;

      -- Failure
      failure_if(logger, True, "message");
      check_only_log(logger, "message", failure);

      failure_if(logger, False, "message");
      check_no_log;

      unmock(logger);

    elsif run("Test conditional default logs") then
      mock(default_logger);

      -- Warning
      warning_if(True, "message");
      check_only_log(default_logger, "message", warning);

      warning_if(False, "message");
      check_no_log;

      -- Error
      error_if(True, "message");
      check_only_log(default_logger, "message", error);

      error_if(False, "message");
      check_no_log;

      -- Failure
      failure_if(True, "message");
      check_only_log(default_logger, "message", failure);

      failure_if(False, "message");
      check_no_log;

      unmock(default_logger);

    elsif run("Disabled log does not stop simulation") then
      set_stop_count(logger, warning, 1);

      -- Disabled log level should not stop simulation
      disable(logger, warning);
      warning(logger, "message");

      -- But still be counted
      assert_equal(get_log_count(logger, warning), 1);

    elsif run("Disabled log is not visible") then
      init_log_handler(file_handler, file_name => log_file_name, format => raw);
      warning(logger, "message");
      set_string(entries, "0", "message");
      check_log_file(file_handler, log_file_name, entries);

      init_log_handler(file_handler, file_name => log_file_name, format => raw);
      disable(logger, warning);
      assert_false(is_visible(logger, warning));
      warning(logger, "message");
      set_string(entries, "0", "message");
      check_empty_log_file(log_file_name);

   elsif run("many log files") then
     set_format(display_handler, format => raw);

     for i in file_handlers'range loop
       file_handlers(i) := new_log_handler(log_file_name & integer'image(i),
                                           format => raw,
                                           use_color => false);
       loggers(i) := get_logger("log_to_file" & integer'image(i));
       set_log_handlers(loggers(i), (0 => file_handlers(i)));
       show(loggers(i), file_handlers(i), info);
     end loop;

     for i in file_handlers'range loop
       info(loggers(i), "a " & integer'image(i));
       info(loggers(i), "b " & integer'image(i));
       info(loggers(i), "c " & integer'image(i));
     end loop;

     for i in file_handlers'range loop
       set_string(entries, "0", "a " & integer'image(i));
       set_string(entries, "1", "b " & integer'image(i));
       set_string(entries, "2", "c " & integer'image(i));

       check_log_file(file_handlers(i), log_file_name & integer'image(i), entries);
     end loop;

   elsif run("Test logger to/from integer conversion") then
     assert_true(to_logger(to_integer(logger)) = logger);
     assert_true(to_logger(to_integer(null_logger)) = null_logger);

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
