-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;


use work.queue_pkg.all;
use work.queue_pool_pkg.all;


entity tb_queue_pool is
  generic (runner_cfg : string);
end entity;

architecture a of tb_queue_pool is
begin
  main : process
    variable pool : queue_pool_t;
    variable queue : queue_t;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("Test default pool is null") then
      assert pool = null_queue_pool report "Expected null pool";

    elsif run("Test allocated queue is empty") then
      pool := new_queue_pool;
      queue := new_queue(pool);
      assert queue /= null_queue report "Expected non null queue";
      check_equal(length(queue), 0);
      recycle(pool, queue);

    elsif run("Test recycled queue is null") then
      pool := new_queue_pool;
      queue := new_queue(pool);
      assert queue /= null_queue report "Expected non null queue";
      recycle(pool, queue);
      assert queue = null_queue report "Expected null queue";
    end if;
    test_runner_cleanup(runner);
  end process;
end architecture;
