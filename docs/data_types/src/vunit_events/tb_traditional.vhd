-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.runner_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

entity tb_traditional is
  generic(
    runner_cfg : string
  );
end entity;

architecture tb of tb_traditional is
  signal new_data_set : boolean := false;
  signal n_event_listener_events : natural := 0;
  signal data : integer;

  constant file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "log.txt"), use_color => true);
  constant log_handlers : log_handler_vec_t := (display_handler, file_handler);

  procedure handle(data : integer) is
  begin
    -- Do something with data
  end;
begin

  test_runner : process
    procedure produce_data(data_set : integer) is
    begin
      data <= data_set;
      wait for 1 ns;
    end;
  begin
    for idx in log_handlers'range loop
      show_all(log_handlers(idx));
      hide_all(get_logger("runner"), log_handlers(idx));
      show(get_logger("runner"), log_handlers(idx), (failure, error, warning));
    end loop;
    set_log_handlers(root_logger, log_handlers);

    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test with non-toggling event signal and an event listener") then
        -- start_snippet notify_with_boolean_event
        for data_set in 1 to 3 loop
          produce_data(data_set);
          new_data_set <= true;
        end loop;
      -- end_snippet notify_with_boolean_event

      elsif run("Test with toggling event signal") then
        -- start_snippet notify_with_toggling_event
        for data_set in 1 to 3 loop
          produce_data(data_set);
          new_data_set <= not new_data_set;
        end loop;
        -- end_snippet notify_with_toggling_event
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  -- start_snippet listening_to_vhdl_events
  listening_to_vhdl_events : process is
    constant logger : logger_t := get_logger("Process waiting on VHDL events");
  begin
    -- start_snippet wait_on_signal_event
    wait on new_data_set;
    -- end_snippet wait_on_signal_event
    trace(logger, "Got new data set");
    handle(data);
  end process;
  -- end_snippet listening_to_vhdl_events

  -- start_snippet listening_to_vhdl_transactions
  listening_to_vhdl_transactions : process is
    constant logger : logger_t := get_logger("Process waiting on VHDL transactions");
  begin
    -- start_snippet wait_on_signal_transaction
    wait on new_data_set'transaction;
    -- end_snippet wait_on_signal_transaction
    trace(logger, "Got new data set");
    handle(data);
  end process;
  -- end_snippet listening_to_vhdl_transactions

  test_runner_watchdog(runner, 500 ns);

end architecture;
