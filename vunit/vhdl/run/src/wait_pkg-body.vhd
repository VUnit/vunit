-- This package provides wait procedures that will produce a log if they
-- are waiting when the test runner watchdog times out.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.run_pkg.all;
use std.textio.all;

package body wait_pkg is
  function timeout_msg(
    msg : string := "") return string is
  begin
    if msg = "" then
      return default_timeout_msg_tag;
    else
      return default_timeout_msg_tag & msg;
    end if;
  end;

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

  function create_timeout_msg(
    procedure_name                      : string;
    remaining_timeout, original_timeout : time;
    custom_msg                          : string := "";
    condition                           : string := "") return string is
    variable msg : line;

    function has_tag (custom_msg : string) return boolean is
    begin
      if custom_msg'length < default_timeout_msg_tag'length then
        return false;
      else
        return custom_msg(custom_msg'left to custom_msg'left + default_timeout_msg_tag'length - 1) = default_timeout_msg_tag;
      end if;
    end;
  begin
    if not has_tag(custom_msg) then
      return custom_msg;
    end if;

    write(msg, "Test runner timeout while blocking on " & procedure_name & ".");

    if custom_msg'length > default_timeout_msg_tag'length then
      write(msg, LF & custom_msg(custom_msg'left + default_timeout_msg_tag'length to custom_msg'right));
    end if;

    if condition /= "" then
      write(msg, LF & condition);
    end if;

    if original_timeout /= max_timeout then
      write(msg, LF & time'image(remaining_timeout) & " out of " & time'image(original_timeout) &
            " remaining on local timeout.");
    end if;

    return msg.all;
  end;

  procedure wait_on(
    signal source      : in boolean;
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant msg       : in string       := default_timeout_msg_tag;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : time := timeout;
    variable do_exit           : boolean;
  begin

    loop
      wait_no_msg(source, condition, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger,
           create_timeout_msg("wait_on", remaining_timeout, timeout,
                              msg, "Condition is " & boolean'image(condition) & "."),
           line_num => line_num, file_name => file_name);

    end loop;
  end;

  procedure wait_on(
    signal source      : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant msg       : in string       := default_timeout_msg_tag;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : delay_length := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(source, vunit_true_boolean_signal, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger,
           create_timeout_msg("wait_on", remaining_timeout, timeout, msg),
           line_num => line_num, file_name => file_name);
    end loop;
  end;

  procedure wait_until(
    signal condition   : in boolean;
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant msg       : in string       := default_timeout_msg_tag;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : delay_length := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(condition, condition, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger,
           create_timeout_msg("wait_until", remaining_timeout, timeout, msg),
           line_num => line_num, file_name => file_name);
    end loop;
  end;

  procedure wait_for(
    constant timeout   : in delay_length := max_timeout;
    constant logger    : in logger_t     := default_logger;
    constant msg       : in string       := default_timeout_msg_tag;
    constant line_num  : in natural      := 0;
    constant file_name : in string       := "") is
    variable remaining_timeout : delay_length := timeout;
    variable do_exit           : boolean;
  begin
    loop
      wait_no_msg(vunit_true_boolean_signal, vunit_true_boolean_signal, remaining_timeout, do_exit);
      exit when do_exit;

      info(logger,
           create_timeout_msg("wait_for", remaining_timeout, timeout, msg),
           line_num => line_num, file_name => file_name);
    end loop;
  end;

  procedure sense(
    signal event  : inout boolean;
    signal s1, s2 : in    boolean) is
  begin
    wait on s1, s2;
    event <= not event;
  end;

  procedure sense(
    signal event      : inout boolean;
    signal s1, s2, s3 : in    boolean) is
  begin
    wait on s1, s2, s3;
    event <= not event;
  end;

  procedure sense(
    signal event          : inout boolean;
    signal s1, s2, s3, s4 : in    boolean) is
  begin
    wait on s1, s2, s3, s4;
    event <= not event;
  end;

  procedure sense(
    signal event              : inout boolean;
    signal s1, s2, s3, s4, s5 : in    boolean) is
  begin
    wait on s1, s2, s3, s4, s5;
    event <= not event;
  end;

  procedure sense(
    signal event                  : inout boolean;
    signal s1, s2, s3, s4, s5, s6 : in    boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6;
    event <= not event;
  end;

  procedure sense(
    signal event                      : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7 : in    boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7;
    event <= not event;
  end;

  procedure sense(
    signal event                          : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8 : in    boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7, s8;
    event <= not event;
  end;

  procedure sense(
    signal event                              : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8, s9 : in    boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7, s8, s9;
    event <= not event;
  end;

  procedure sense(
    signal event                                   : inout boolean;
    signal s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 : in    boolean) is
  begin
    wait on s1, s2, s3, s4, s5, s6, s7, s8, s9, s10;
    event <= not event;
  end;

end package body;
