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
use vunit_lib.event_pkg.all;
use vunit_lib.event_common_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity tb_event_pkg is
  generic(
    runner_cfg : string);
end entity;

architecture test_fixture of tb_event_pkg is
  constant request_queue : queue_vec_t(1 to 2) := (new_queue, new_queue);
  constant number : integer_vector_ptr_t := new_integer_vector_ptr(2);
  constant number_produced_idx : natural := 0;
  constant number_observed_idx : natural := 1;
  type bool_vector is array (natural range <>) of boolean;
  signal new_queue_item : bool_vector(1 to 2) := (others => false);
  signal acted_on_event_4 : boolean := false;
  signal acted_on_event_5 : boolean := false;

  signal event_1 : event_t := new_event(get_id("tb_event_pkg:my_event_1"));
  signal event_2 : event_t := new_event(get_id("tb_event_pkg:my_event_2"));
  signal event_3 : event_t := new_event(get_id("tb_event_pkg:event_3"));
  signal event_4 : event_t := new_event("tb_event_pkg:my_event_4");
  signal event_5 : event_t := new_event;
  signal number_event : event_t := new_event;
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
        check_equal(name(event_1), "my_event_1");
        check_equal(name(event_2), "my_event_2");
        check_equal(name(event_5), "_event_4");
        check_equal(full_name(event_1), "tb_event_pkg:my_event_1");
        check_equal(full_name(event_2), "tb_event_pkg:my_event_2");
        check_equal(full_name(event_5), "vunit_lib:event_pkg:_event_4");

      elsif run("Test getting event id") then
        check(id(event_1) = get_id("tb_event_pkg:my_event_1"));
        check(id(event_2) = get_id("tb_event_pkg:my_event_2"));
        check(id(event_5) /= null_id);

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
        check_false(is_active_msg(event_1), result("for is_active_msg(event_1)"));
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
        notify(event_4);
        wait for 1 ps;
        check_log(event_pkg_logger, "Event 4", info, 101 ps);
        unmock(runner_trace_logger);
        unmock(event_pkg_logger);

      elsif run("Test log_active with no event activation") then
        mock(runner_trace_logger, error);
        mock(event_pkg_logger, info);
        wait until log_active(event_1) for 1 ns;
        check_false(is_active(event_1), result("for is_active(event_1)"));
        check_equal(now, 1 ns, result("for timeout"));
        check_no_log;
        unmock(runner_trace_logger);
        unmock(event_pkg_logger);

      elsif run("Test log_active with event activation") then
        mock(runner_trace_logger, error);
        mock(event_pkg_logger, info);
        activate_event(1, 100 ps, 1);
        wait until log_active(event_1, decorate("by observer")) for 1 ns;
        check_equal(now, 1 ns);
        check_log(event_pkg_logger, "Event tb_event_pkg:my_event_1 activated by observer", info, 100 ps);
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

      elsif run("Test that events in adjacent delta cycles are detected") then
        while now < 1.4 ns loop
          wait until is_active(event_3) for 1 ns;
          if is_active(event_3) then
            event_counter := event_counter + 1;
          end if;
        end loop;
        check_equal(event_counter, 4);

      elsif run("Test that an activated process is activated before notify returns") then
        notify(event_4, event_5);
        check_true(acted_on_event_4);
        check_true(acted_on_event_5);

      elsif run("Test that notify delta delay can be controlled") then
        notify(event_4, event_5, 0);
        check_false(acted_on_event_4);
        check_false(acted_on_event_5);

      elsif run("Test event grouping to avoid delta limits") then
        wait for 1 ps;
        -- 10000 back-to-back events would normally hit the simulator's
        -- limit for the maximum number of delta cycles
        for i in 1 to 10000 loop
          set(number, number_produced_idx, i);
          -- One solution, useful in some use cases, is to only generate an event
          -- if not already active, a single event representing the full set of events
          -- (number increments). Depending on order in which the simulator evaluates
          -- processes, this may cause an observer to miss number increments. See
          -- number_observer process to see how this is managed.
          if not is_active(number_event) then
            notify(number_event, n_delta_cycles => 0);
          end if;
        end loop;
        wait for 1 ps;
        check_equal(get(number, number_observed_idx), get(number, number_produced_idx));

      elsif run("Test condition_operator function") then
        check_true(condition_operator(bit'('1')));
        check_true(condition_operator(std_ulogic'('1')));
        check_true(condition_operator(std_ulogic'('H')));
        check_true(condition_operator(true));

        check_false(condition_operator(bit'('0')));
        check_false(condition_operator(std_ulogic'('0')));
        check_false(condition_operator(std_ulogic'('L')));
        check_false(condition_operator(std_ulogic'('X')));
        check_false(condition_operator(std_ulogic'('U')));
        check_false(condition_operator(std_ulogic'('W')));
        check_false(condition_operator(std_ulogic'('-')));
        check_false(condition_operator(std_ulogic'('Z')));
        check_false(condition_operator(false));
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 ns, do_runner_cleanup => false);

  number_observer : process is
  begin
    -- The avoid the risk that an observer of the group event fails to see
    -- all number increments, it must also act on when the event is inactivated
    -- after the last of the original event occurred (last number increment).
    wait on number_event; -- Equivalent to wait until is_active(number_event) or not is_active(number_event)
    set(number, number_observed_idx, get(number, number_produced_idx));
  end process;

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

  event_4_observer : process
  begin
    wait until is_active_msg(event_4, "Event 4");
    acted_on_event_4 <= true;
    wait;
  end process;

  event_5_observer : process
  begin
    wait until is_active(event_5);
    acted_on_event_5 <= true;
    wait;
  end process;

  delta_event_producers : for delta_delay in 0 to 3 generate
    process
    begin
      wait for 0.5 ns;
      for iter in 1 to delta_delay loop
        wait for 0 ns;
      end loop;
      notify(event_3);
      wait;
    end process;
  end generate;

end architecture;
