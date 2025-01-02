-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;
use work.sync_pkg.all;

entity tb_sync_pkg is
  generic (runner_cfg : string);
end entity;

architecture a of tb_sync_pkg is
  constant actor : actor_t := new_actor;
begin

  main : process
    variable start : time;
  begin
    test_runner_setup(runner, runner_cfg);

    start := now;
    wait_for_time(net, actor, 11 ns);
    wait_until_idle(net, actor);
    check_equal(now - start, 11 ns, "wait for time mismatch");

    start := now;
    wait_for_time(net, actor, 37 ms);
    wait_until_idle(net, actor);
    check_equal(now - start, 37 ms, "wait for time mismatch");

    mock(com_logger, failure);
    start := now;
    wait_for_time(net, actor, 37 ms);
    wait_until_idle(net, actor, 10 ms);
    check_log(com_logger, "TIMEOUT.", failure, start + 10 ms);
    check_only_log(get_logger("vunit_lib:com"), "NULL MESSAGE ERROR.", failure, start + 10 ms);
    unmock(com_logger);

    test_runner_cleanup(runner);
  end process;

  support : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, actor, msg);
    msg_type := message_type(msg);
    handle_sync_message(net, msg_type, msg);
    unexpected_msg_type(msg_type);
  end process;
end architecture;
