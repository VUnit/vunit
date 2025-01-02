-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.id_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.string_ops.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.event_common_pkg.all;
use vunit_lib.event_private_pkg.all;
use vunit_lib.event_pkg.all;
use vunit_lib.queue_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

use vunit_lib.runner_pkg.all;

entity tb_event_private_pkg is
  generic(
    runner_cfg : string);
end entity;

architecture test_fixture of tb_event_private_pkg is
  constant request_queue : queue_vec_t(1 to 2) := (new_queue, new_queue);
  type bool_vector is array (natural range <>) of boolean;
  signal new_queue_item : bool_vector(1 to 2) := (others => false);
  signal acted_on_basic_event_4 : boolean := false;
  signal acted_on_basic_event_5 : boolean := false;

  signal basic_event_1 : basic_event_t := new_basic_event(vunit_error_event);
  signal basic_event_2 : basic_event_t := new_basic_event(runner_cleanup_event);
  signal basic_event_3 : basic_event_t := new_basic_event(com_net_event);
  signal basic_event_4 : basic_event_t := new_basic_event(runner_timeout_update_event);
  signal basic_event_5 : basic_event_t := new_basic_event(runner_timeout_event);
  signal basic_event_6 : basic_event_t := new_basic_event(runner_phase_event);
begin
  test_runner : process
    procedure activate_event(event_number : natural range 1 to 2; event_time : time; queue_idx : positive range request_queue'range) is
    begin
      push(request_queue(queue_idx), event_time);
      push(request_queue(queue_idx), event_number);
      new_queue_item(queue_idx) <= true;
      wait until new_queue_item(queue_idx);
      new_queue_item(queue_idx) <= false;
    end;

    variable event_counter : natural := 0;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test getting event names") then
        check_equal(name(basic_event_1), "vunit_error");
        check_equal(name(basic_event_2), "cleanup");
        check_equal(name(basic_event_3), "net");
        check_equal(name(basic_event_4), "timeout_update");
        check_equal(name(basic_event_5), "timeout");
        check_equal(name(basic_event_6), "phase");
        check_equal(full_name(basic_event_1), "vunit_lib:vunit_error");
        check_equal(full_name(basic_event_2), "runner:cleanup");
        check_equal(full_name(basic_event_3), "vunit_lib:com:net");
        check_equal(full_name(basic_event_4), "runner:timeout_update");
        check_equal(full_name(basic_event_5), "runner:timeout");
        check_equal(full_name(basic_event_6), "runner:phase");

      elsif run("Test that no basic event leads to no event activation") then
        wait until is_active(basic_event_1) for 1 ns;
        check_false(is_active(basic_event_1), result("for is_active(basic_event_1)"));
        check_equal(now, 1 ns, result("for timeout"));

      elsif run("Test that a notified basic event leads to an event activation") then
        activate_event(1, 100 ps, 1);
        wait until is_active(basic_event_1) for 1 ns;
        check_true(is_active(basic_event_1), result("for is_active(basic_event_1)"));
        check_equal(now, 100 ps, result("for active time"));

      elsif run("Test is_active_msg with no basic event activation") then
        mock(runner_trace_logger, error);
        mock(event_pkg_logger, info);
        wait until is_active_msg(basic_event_1) for 1 ns;
        check_false(is_active(basic_event_1), result("for is_active_msg(basic_event_1)"));
        check_equal(now, 1 ns, result("for timeout"));
        check_no_log;
        unmock(runner_trace_logger);
        unmock(event_pkg_logger);

      elsif run("Test is_active_msg with event activation") then
        mock(runner_trace_logger, error);
        mock(event_pkg_logger, info);
        activate_event(1, 100 ps, 1);
        wait until is_active(basic_event_1);
        check_equal(now, 100 ps);
        wait for 1 ps;
        check_log(event_pkg_logger, "Event vunit_lib:vunit_error activated by observer", info, 100 ps);
        check_log(event_pkg_logger, "Event vunit_lib:vunit_error activated by observer", info, 100 ps);
        unmock(runner_trace_logger);
        unmock(event_pkg_logger);

      elsif run("Test multiple notifiers") then
        activate_event(1, 100 ps, 1);
        activate_event(1, 700 ps, 2);
        wait until is_active(basic_event_1) for 1 ns;
        check_true(is_active(basic_event_1), result("for is_active(basic_event_1)"));
        check_equal(now, 100 ps, result("for activation time"));
        wait until is_active(basic_event_1) for 1 ns;
        check_true(is_active(basic_event_1), result("for is_active(basic_event_1)"));
        check_equal(now, 700 ps, result("for activation time"));

      elsif run("Test for basic event independence") then
        activate_event(1, 100 ps, 1);
        activate_event(2, 200 ps, 2);
        wait until is_active(basic_event_1) or is_active(basic_event_2) for 1 ns;
        check_true(is_active(basic_event_1), result("for is_active(basic_event_1)"));
        check_false(is_active(basic_event_2), result("for is_active(basic_event_2)"));
        check_equal(now, 100 ps, result("for active time"));
        wait until is_active(basic_event_1) or is_active(basic_event_2) for 1 ns;
        check_false(is_active(basic_event_1), result("for is_active(basic_event_1)"));
        check_true(is_active(basic_event_2), result("for is_active(basic_event_2)"));
        check_equal(now, 200 ps, result("for active time"));

      elsif run("Test that events in adjacent delta cycles are detected") then
        while now < 1.4 ns loop
          wait until is_active(basic_event_3) for 1 ns;
          if is_active(basic_event_3) then
            event_counter := event_counter + 1;
          end if;
        end loop;
        check_equal(event_counter, 4);

      elsif run("Test that an activated process is activated before notify returns") then
        notify(basic_event_4, basic_event_5);
        check_true(acted_on_basic_event_4);
        check_true(acted_on_basic_event_5);

      elsif run("Test that notify delta delay can be controlled") then
        notify(basic_event_4, basic_event_5, 0);
        check_false(acted_on_basic_event_4);
        check_false(acted_on_basic_event_5);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 ns, do_runner_cleanup => false);

  event_producer_generator : for queue_idx in request_queue'range generate
    process
    begin
      if is_empty(request_queue(queue_idx)) then
        wait until new_queue_item(queue_idx);
      end if;

      wait for pop(request_queue(queue_idx)) - now;
      if pop(request_queue(queue_idx)) = 1 then
        notify(basic_event_1);
      else
        notify(basic_event_2);
      end if;
    end process;
  end generate;

  event_observer1 : process
  begin
    wait until is_active_msg(basic_event_1, decorate("by observer"));
    wait;
  end process;

  event_observer2 : process
  begin
    wait until is_active_msg(basic_event_1, decorate("by observer"));
    wait;
  end process;

  basic_event_4_observer : process
  begin
    wait until is_active(basic_event_4);
    acted_on_basic_event_4 <= true;
    wait;
  end process;

  basic_event_5_observer : process
  begin
    wait until is_active(basic_event_5);
    acted_on_basic_event_5 <= true;
    wait;
  end process;

  delta_event_producers : for delta_delay in 0 to 3 generate
    process
    begin
      wait for 0.5 ns;
      for iter in 1 to delta_delay loop
        wait for 0 ns;
      end loop;
      notify(basic_event_3);
      wait;
    end process;
  end generate;

end architecture;
