-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

use vunit_lib.runner_pkg.all;

entity tb_event_pkg is
  generic(
    runner_cfg : string);
end entity;

architecture test_fixture of tb_event_pkg is
  constant request_queue : queue_vec_t(1 to 2) := (new_queue, new_queue);
  signal new_queue_item : boolean_vector(1 to 2) := (others => false);

  signal event_1 : event_t := new_event(get_id("tb_event_pkg:my_event_1"));
  signal event_2 : event_t := new_event(get_id("tb_event_pkg:my_event_2"));
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
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test getting event names") then
        check_equal(name(event_1), "my_event_1");
        check_equal(name(event_2), "my_event_2");
        check_equal(full_name(event_1), "tb_event_pkg:my_event_1");
        check_equal(full_name(event_2), "tb_event_pkg:my_event_2");

      elsif run("Test getting event id") then
        check(id(event_1) = get_id("tb_event_pkg:my_event_1"));
        check(id(event_2) = get_id("tb_event_pkg:my_event_2"));

      elsif run("Test presence of previously created events") then
        check_true(has_event(get_id("tb_event_pkg:my_event_1")));
        check_true(has_event(get_id("tb_event_pkg:my_event_2")));
        check_false(has_event(get_id("tb_event_pkg:my_event_3")));

      elsif run("Test that two events can't be created for the same id") then
        mock(event_pkg_logger, error);
        event_2 <= new_event(id(event_1));
        wait for 0 ns;
        check_only_log(event_pkg_logger, "Event already created for tb_event_pkg:my_event_1.", error);
        check(event_2 = null_event);
        unmock(event_pkg_logger);

      elsif run("Test that no event leads to no event activation") then
        wait until is_active(event_1) for 1 ns;
        check_false(is_active(event_1), result("for is_active(event_1)"));
        check_equal(now, 1 ns, result("for timeout"));

      elsif run("Test that a notified event leads to an event activation") then
        activate_event(1, 100 ps, 1);
        wait until is_active(event_1) for 1 ns;
        check_true(is_active(event_1), result("for is_active(event_1)"));
        check_equal(now, 100 ps, result("for active time"));

      elsif run("Test is_active_msg with no event activation") then
        mock(runner_trace_logger, error);
        mock(event_pkg_logger, info);
        wait until is_active_msg(event_1) for 1 ns;
        check_false(is_active(event_1), result("for is_active_msg(event_1)"));
        check_equal(now, 1 ns, result("for timeout"));
        check_no_log;
        unmock(runner_trace_logger);
        unmock(event_pkg_logger);

      elsif run("Test is_active_msg with event activation") then
        mock(runner_trace_logger, error);
        mock(event_pkg_logger, info);
        activate_event(1, 100 ps, 1);
        wait until is_active(event_1);
        check_equal(now, 100 ps);
        wait for 1 ps;
        check_log(event_pkg_logger, "Event tb_event_pkg:my_event_1 activated by observer", info, 100 ps);
        check_log(event_pkg_logger, "Event tb_event_pkg:my_event_1 activated by observer", info, 100 ps);
        unmock(runner_trace_logger);
        unmock(event_pkg_logger);

      elsif run("Test multiple notifiers") then
        activate_event(1, 100 ps, 1);
        activate_event(1, 700 ps, 2);
        wait until is_active(event_1) for 1 ns;
        check_true(is_active(event_1), result("for is_active(event_1)"));
        check_equal(now, 100 ps, result("for activation time"));
        wait until is_active(event_1) for 1 ns;
        check_true(is_active(event_1), result("for is_active(event_1)"));
        check_equal(now, 700 ps, result("for activation time"));

      elsif run("Test for event independence") then
        activate_event(1, 100 ps, 1);
        activate_event(2, 200 ps, 2);
        wait until is_active(event_1) or is_active(event_2) for 1 ns;
        check_true(is_active(event_1), result("for is_active(event_1)"));
        check_false(is_active(event_2), result("for is_active(event_2)"));
        check_equal(now, 100 ps, result("for active time"));
        wait until is_active(event_1) or is_active(event_2) for 1 ns;
        check_false(is_active(event_1), result("for is_active(event_1)"));
        check_true(is_active(event_2), result("for is_active(event_2)"));
        check_equal(now, 200 ps, result("for active time"));

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
        notify(event_1);
      else
        notify(event_2);
      end if;
    end process;
  end generate;

  event_observer1 : process
  begin
    wait until is_active_msg(event_1, decorate("by observer"));
    wait;
  end process;

  event_observer2 : process
  begin
    wait until is_active_msg(event_1, decorate("by observer"));
    wait;
  end process;

end architecture;
