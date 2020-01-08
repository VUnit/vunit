-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_levels_pkg.all;

use vunit_lib.sync_point_pkg.all;
use vunit_lib.id_pkg.all;

entity tb_sync_point is
  generic(runner_cfg : string);
end entity;

architecture a of tb_sync_point is
  constant test_logger : logger_t := get_logger("Test logger");
  constant checker_logger : logger_t := get_logger("Checker logger");
  constant checker : checker_t := new_checker(checker_logger);
  signal uninitialized_sync_point : sync_point_t;
  signal sync_point : sync_point_t := new_sync_point;
  signal my_sync_point : sync_point_t := new_sync_point(new_id("my_sync_point"), test_logger);
  signal custom_checker_sync_point : sync_point_t := new_sync_point(new_id("custom_checker_sync_point"),
                                                                    checker => checker
                                                                   );
  signal single_member_sync_point : sync_point_t := new_sync_point;
  signal multi_member_sync_point : sync_point_t := new_sync_point;
begin
  test_runner : process
    constant runner_logger : logger_t := get_logger("runner");
    variable logger : logger_t;

    variable timestamp : time;
    constant id, id2 : id_t := new_id;
    constant ids : id_vec_t := (id, id2);
    constant my_id : id_t := new_id("my_id");
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      logger := get_logger(name(get_id(sync_point)), sync_point_logger);

      if run("Test that an uninitialized sync point is invalid") then
        check_false(valid(uninitialized_sync_point), result("for sync point validity"));

      elsif run("Test that an initialized sync point is valid") then
        check_true(valid(sync_point), result("for sync point validity"));

      elsif run("Test that sync points are named correctly") then
        check_equal(name(get_id(sync_point)), "sync point 0", result("for unnamed sync point"));
        check_equal(name(get_id(my_sync_point)), "my_sync_point", result("for named sync point"));

      elsif run("Test that a new sync point has no members") then
        check_false(has_members(sync_point), result("for has members"));

      elsif run("Test that a process can join a sync point") then
        check_false(has_members(sync_point), result("for has members"));
        check_false(is_member(sync_point, id), result("for id is member of sync point group"));
        join(sync_point, id);
        check_true(is_member(sync_point, id), result("for id is member of sync point group"));
        check_true(has_members(sync_point), result("for sync point has members"));

      elsif run("Test that a process can leave a sync point") then
        join(sync_point, id);
        check_true(is_member(sync_point, id), result("for id is member of sync point group"));
        check_true(has_members(sync_point), result("for sync point has members"));
        leave(sync_point, id);
        check_false(has_members(sync_point), result("for has members"));
        check_false(is_member(sync_point, id), result("for id is member of sync point group"));

      elsif run("Test that a sync point can have several members") then
        join(sync_point, ids);
        check_true(is_member(sync_point, id), result("for id is member of sync point group"));
        check_true(is_member(sync_point, id2), result("for id2 is member of sync point group"));
        check_true(has_members(sync_point), result("for sync point has members"));
        leave(sync_point, ids);
        check_false(is_member(sync_point, id), result("for id is member of sync point group"));
        check_false(is_member(sync_point, id2), result("for id2 is member of sync point group"));
        check_false(has_members(sync_point), result("for sync point has members"));

      elsif run("Test that a processes is not blocked by a sync point without members") then
        timestamp := now;
        sync(sync_point);
        check_equal(now - timestamp, 0 ns, result("for waiting a sync point without members"));

      elsif run("Test that a processes is blocked by a sync point with single member") then
        timestamp := now;
        wait until has_members(single_member_sync_point);
        sync(single_member_sync_point);
        check_equal(now - timestamp, 2 ns, result("for waiting on a sync point with members"));

      elsif run("Test that a processes is blocked by a sync point with several members") then
        timestamp := now;
        wait until has_members(multi_member_sync_point);
        sync(multi_member_sync_point);
        check_equal(now - timestamp, 11 ns, result("for waiting on a multi-member sync point"));

      elsif run("Test leaving and syncing with a single call to sync") then
        timestamp := now;
        wait until has_members(multi_member_sync_point);
        join(multi_member_sync_point, id);
        sync(multi_member_sync_point, id);
        check_equal(now - timestamp, 11 ns, result("for leaving and waiting on a multi-member sync point"));

      elsif run("Test sync and join and leave race condition") then
        wait for 3 ns;

      elsif run("Test that a process can join and leave a sync point several times") then
        for i in 1 to 3 loop
          check_false(is_member(sync_point, id), result("for id is member of sync point group"));
          join(sync_point, id);
          check_true(is_member(sync_point, id), result("for id is member of sync point group"));
          check_true(has_members(sync_point), result("for sync point with members"));
          leave(sync_point, id);
          check_false(is_member(sync_point, id), result("for id is member of sync point group"));
          check_false(has_members(sync_point), result("for sync point without members"));
        end loop;

      elsif run("Test that a process cannot join a sync point multiple times without leaving in between") then
        join(sync_point, id);
        mock(logger, error);
        join(sync_point, id);
        check_only_log(logger, "Cannot use " & name(id) & " to join " & name(get_id(sync_point)) & " again.", error);
        unmock(logger);

      elsif run("Test that a process cannot leave a sync point without being a member") then
        join(sync_point, id);
        leave(sync_point, id);
        mock(logger, error);
        leave(sync_point, id);
        check_only_log(logger, "Cannot use " & name(id) & " to leave " & name(get_id(sync_point)) &
        " without joining it first.", error);
        unmock(logger);

      elsif run("Test that different sync points can be join and left with the same id") then
        join(sync_point, id);
        check_true(has_members(sync_point), result("for joining sync_point"));
        check_false(has_members(my_sync_point), result("for joining my_sync_point"));
        check_true(is_member(sync_point, id), result("for id is member of sync_point group"));
        check_false(is_member(my_sync_point, id), result("for id is member of my_sync_point group"));
        join(my_sync_point, id);
        check_true(has_members(sync_point), result("for joining sync_point"));
        check_true(has_members(my_sync_point), result("for joining my_sync_point"));
        check_true(is_member(sync_point, id), result("for id is member of sync_point group"));
        check_true(is_member(my_sync_point, id), result("for id is member of my_sync_point group"));
        leave(sync_point, id);
        check_false(has_members(sync_point), result("for joining sync_point"));
        check_true(has_members(my_sync_point), result("for joining my_sync_point"));
        check_false(is_member(sync_point, id), result("for id is member of sync_point group"));
        check_true(is_member(my_sync_point, id), result("for id is member of my_sync_point group"));
        leave(my_sync_point, id);
        check_false(has_members(sync_point), result("for joining sync_point"));
        check_false(has_members(my_sync_point), result("for joining my_sync_point"));
        check_false(is_member(sync_point, id), result("for id is member of sync_point group"));
        check_false(is_member(my_sync_point, id), result("for id is member of my_sync_point group"));

      elsif run("Test that a sync point can have a custom checker") then
        join(custom_checker_sync_point, id);
        mock(checker_logger, error);
        join(custom_checker_sync_point, id);
        check_only_log(checker_logger, "Cannot use " & name(id) &
        " to join custom_checker_sync_point again.", error
        );
        unmock(checker_logger);

      elsif run("Test that sync point join and leave events are logged") then
        mock(test_logger, info);
        join(my_sync_point, id);
        check_log(test_logger, "Joining my_sync_point with " & name(id) & ".", info, 0 ns);
        wait for 1 ns;
        leave(my_sync_point, id);
        check_log(test_logger, "Leaving my_sync_point with " & name(id) & ".", info, 1 ns);
        unmock(test_logger);

      elsif run("Test that unsynchronized sync points are identified on watchdog timeout") then
        join(my_sync_point, id);
        join(my_sync_point, my_id);
        mock(test_logger, debug);
        mock(runner_logger);

        wait until timeout_notification(runner);
        wait for 1 ps;

        check_log(test_logger, "Test runner timeout while my_sync_point was waiting for " &
          name(id) & ", my_id.", debug, 15 ns);

        check_log(runner_logger, "Test runner timeout after " & time'image(15 ns) & ".", error, 15 ns);

        unmock(test_logger);
        unmock(runner_logger);

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 15 ns, do_runner_cleanup => false);

  process
    constant id : id_t := new_id;
  begin
    wait for 1 ns;
    join(single_member_sync_point, id);
    wait for 1 ns;
    leave(single_member_sync_point, id);
    wait;
  end process;

  processes_joining_the_same_sync_point : for i in 1 to 10 generate
  begin
    process
      constant id : id_t := new_id;
    begin
      wait for 1 ns;
      join(multi_member_sync_point, id);
      wait for i * ns;
      leave(multi_member_sync_point, id);
      wait;
    end process;
  end generate;

  process
  begin
    wait for 1 ps;
    sync(my_sync_point);
    wait;
  end process;

  race_condition_test : block is
    signal early_sync_points : sync_point_vec_t(1 to 10) := (
      new_sync_point(new_id("sp1")),
      new_sync_point(new_id("sp2")),
      new_sync_point(new_id("sp3")),
      new_sync_point(new_id("sp4")),
      new_sync_point(new_id("sp5")),
      new_sync_point(new_id("sp6")),
      new_sync_point(new_id("sp7")),
      new_sync_point(new_id("sp8")),
      new_sync_point(new_id("sp9")),
      new_sync_point(new_id("sp10"))
    );
  begin
    syncing_processes : for i in early_sync_points'range generate
      process
      begin
        sync(early_sync_points(i));
        wait for 1 ns;
        if enabled("Test sync and join race condition") then
          check_equal(now, 2 ns);
        end if;
        wait;
      end process;
    end generate;

    joining_process : process
      constant id : id_t := new_id;
    begin
      join(early_sync_points(1), id);
      join(early_sync_points(2), early_sync_points(3), id);
      join(early_sync_points(4), early_sync_points(5), early_sync_points(6), id);
      join(early_sync_points(7), early_sync_points(8), early_sync_points(9), early_sync_points(10), id);

      wait for 1 ns;

      sync(early_sync_points(1), id);
      sync(early_sync_points(2), id);
      sync(early_sync_points(3), id);
      sync(early_sync_points(4), id);
      sync(early_sync_points(5), id);
      sync(early_sync_points(6), id);
      sync(early_sync_points(7), id);
      sync(early_sync_points(8), id);
      sync(early_sync_points(9), id);
      sync(early_sync_points(10), id);

      wait;
    end process;
  end block;


end architecture;
