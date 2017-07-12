-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com


library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;
use work.sync_pkg.all;
use work.msg_types_pkg.all;

entity tb_sync_pkg is
  generic (runner_cfg : string);
end entity;

architecture a of tb_sync_pkg is
  constant actor : actor_t := create;
begin

  main : process
    variable start : time;
  begin
    test_runner_setup(runner, runner_cfg);

    start := now;
    wait_for_time(event, actor, 11 ns);
    await_completion(event, actor);
    check_equal(now - start, 11 ns, "wait for time mismatch");

    start := now;
    wait_for_time(event, actor, 37 ms);
    await_completion(event, actor);
    check_equal(now - start, 37 ms, "wait for time mismatch");

    test_runner_cleanup(runner);
  end process;

  support : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(event, actor, msg);
    msg_type := pop_msg_type(msg);
    handle_sync_message(event, msg_type, msg);
    unexpected_msg_type(msg_type);
  end process;
end architecture;
