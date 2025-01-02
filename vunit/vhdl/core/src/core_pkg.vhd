-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.stop_pkg;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;

package core_pkg is
  procedure setup(file_name : string);
  procedure test_start(test_name : string);
  procedure test_suite_done;
  procedure stop(status : natural);

  -- @TODO add core acceptance tests
  procedure core_failure(msg : string);
  procedure mock_core_failure;
  procedure check_core_failure(msg : string := "");
  procedure unmock_core_failure;
  procedure check_and_unmock_core_failure(msg : string := "");

end package;

package body core_pkg is
  file test_results : text;

  procedure setup(file_name : string) is
  begin
    file_open(test_results, file_name, write_mode);
  end procedure;

  procedure test_start(test_name : string) is
    variable l : line;
  begin
    write(l, string'("test_start:"));
    write(l,  test_name);
    writeline(test_results, l);
  end procedure;

  procedure test_suite_done is
    variable l : line;
  begin
    write(l, string'("test_suite_done"));
    writeline(test_results, l);
    file_close(test_results);
  end procedure;

  constant is_mocked_idx : natural := 0;
  constant core_failure_called_idx : natural := 1;
  constant core_failure_message_idx : natural := 2;
  constant core_failure_mock_state_length : natural := 3;

  impure function new_core_failure_mock_state return integer_vector_ptr_t is
    constant state : integer_vector_ptr_t := new_integer_vector_ptr(core_failure_mock_state_length);
  begin
    set(state, is_mocked_idx, 0);
    set(state, core_failure_called_idx, 0);
    set(state, core_failure_message_idx, to_integer(new_string_ptr));
    return state;
  end;

  constant core_failure_mock_state : integer_vector_ptr_t := new_core_failure_mock_state;

  procedure mock_core_failure is
  begin
    set(core_failure_mock_state, is_mocked_idx, 1);
    set(core_failure_mock_state, core_failure_called_idx, 0);
  end;

  impure function core_failure_is_mocked return boolean is
  begin
    return get(core_failure_mock_state, is_mocked_idx) = 1;
  end;

  procedure core_failure(msg : string) is
  begin
    if core_failure_is_mocked then
      set(core_failure_mock_state, core_failure_called_idx, 1);
      reallocate(to_string_ptr(get(core_failure_mock_state, core_failure_message_idx)), msg);
    else
      report msg severity failure;
    end if;
  end;

  procedure check_core_failure(msg : string := "") is
    variable got_msg : string_ptr_t;
  begin
    if not core_failure_is_mocked then
      report "core_failure not mocked" severity failure;
    end if;

    if get(core_failure_mock_state, core_failure_called_idx) /= 1 then
      report "core_failure not called" severity failure;
    end if;

    got_msg := to_string_ptr(get(core_failure_mock_state, core_failure_message_idx));
    if msg /= "" and to_string(got_msg) /= msg then
      report "Got core_failure message " & to_string(got_msg) & " expected " & msg severity failure;
    end if;

    set(core_failure_mock_state, core_failure_called_idx, 0);
  end;

  procedure unmock_core_failure is
    variable got_msg : string_ptr_t;
  begin
    if not core_failure_is_mocked then
      report "core_failure not mocked" severity failure;
    end if;

    got_msg := to_string_ptr(get(core_failure_mock_state, core_failure_message_idx));
    if get(core_failure_mock_state, core_failure_called_idx) /= 0 then
      report "core_failure was unexpectedly called with messsage " & to_string(got_msg) severity failure;
    end if;

    set(core_failure_mock_state, is_mocked_idx, 0);
  end;

  procedure check_and_unmock_core_failure(msg : string := "") is
  begin
    check_core_failure(msg);
    unmock_core_failure;
  end;

  procedure stop(status : natural) is
  begin
    stop_pkg.stop(status);
  end;

end package body;
