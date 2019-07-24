-- This package provides wait procedures that will produce a log if they
-- are waiting when the test runner watchdog times out.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.run_pkg.all;

package body wait_pkg is
  procedure wait_no_msg(
    signal source    : in    boolean;
    signal condition : in    boolean;
    variable timeout : inout delay_length;
    variable do_exit : out   boolean
    ) is
    constant t_start : delay_length := now;
  begin
    wait on runner(runner_timeout_idx), source until (source'event and condition) or timeout_notification(runner) for timeout;

    if (source'event and condition) then
      do_exit := true;
      return;
    end if;

    timeout := timeout - (now - t_start);
    do_exit := timeout = 0 ns;
    return;
  end;

  function local_timeout_msg(remaining_timeout, original_timeout : time) return string is
  begin
    if original_timeout = max_timeout then
      return "";
    end if;

    return LF & time'image(remaining_timeout) & " out of " & time'image(original_timeout) &
      " remaining on local timeout.";
  end;

  procedure wait_on(
    signal source      : in boolean;
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : time := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(source, condition, remaining_timeout, do_exit);
      exit when do_exit;

      if condition then
        info(logger, "Test runner timeout while blocking on wait_on." & LF &
             "Condition is true." &
             local_timeout_msg(remaining_timeout, timeout),
             line_num => line_num, file_name => file_name);
      else
        info(logger, "Test runner timeout while blocking on wait_on." & LF &
             "Condition is false." &
             local_timeout_msg(remaining_timeout, timeout),
             line_num => line_num, file_name => file_name);
      end if;
    end loop;
  end;

  procedure wait_on(
    signal source      : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : delay_length := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(source, vunit_true_boolean_signal, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger, "Test runner timeout while blocking on wait_on." &
           local_timeout_msg(remaining_timeout, timeout),
           line_num => line_num, file_name => file_name);
    end loop;
  end;

  procedure wait_until(
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : delay_length := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(condition, condition, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger, "Test runner timeout while blocking on wait_until." &
           local_timeout_msg(remaining_timeout, timeout),
           line_num => line_num, file_name => file_name);
    end loop;
  end;

  procedure wait_for(
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : delay_length := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(vunit_true_boolean_signal, vunit_true_boolean_signal, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger, "Test runner timeout while blocking on wait_for." &
           local_timeout_msg(remaining_timeout, timeout),
           line_num => line_num, file_name => file_name);
    end loop;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2 : in boolean) is
  begin
    wait on s1, s2;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3 : in boolean) is
  begin
    wait on s1, s2, s3;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4 : in boolean) is
  begin
    wait on s1, s2, s3, s4;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5 : in boolean) is
  begin
    wait on s1, s2, s3, s4, s5;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6 : in boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7 : in boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8 : in boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7, s8;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8, s9 : in boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7, s8, s9;
    event <= not event;
  end;

  procedure sense(
    signal event : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 : in boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7, s8, s9, s10;
    event <= not event;
  end;

end package body;
