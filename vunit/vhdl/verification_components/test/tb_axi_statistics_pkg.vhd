-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

use work.axi_pkg.all;
context work.vunit_context;
context work.vc_context;

entity tb_axi_statistics_pkg is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_axi_statistics_pkg is
begin
  main : process
    variable stat, stat2 : axi_statistics_t;
  begin
    test_runner_setup(runner, runner_cfg);
    check(stat = null_axi_statistics);

    while test_suite loop
      deallocate(stat);
      check(stat = null_axi_statistics);

      if run("test new_axi_statistics") then
        stat := new_axi_statistics;
        check_equal(num_bursts(stat), 0);
        check_equal(min_burst_length(stat), 0);
        check_equal(max_burst_length(stat), 0);

        for i in 0 to max_axi4_burst_length loop
          check_equal(get_num_burst_with_length(stat, i), 0);
        end loop;
        check_equal(get_num_burst_with_length(stat, max_axi4_burst_length+1), 0);

        deallocate(stat);
        check(stat = null_axi_statistics);

      elsif run("test add_burst_length") then
        stat := new_axi_statistics;

        add_burst_length(stat, 7);
        add_burst_length(stat, 7);
        add_burst_length(stat, 17);

        check_equal(num_bursts(stat), 3);
        check_equal(min_burst_length(stat), 7);
        check_equal(max_burst_length(stat), 17);

        for i in 0 to max_axi4_burst_length loop
          if i = 7 then
            check_equal(get_num_burst_with_length(stat, i), 2);
          elsif i = 17 then
            check_equal(get_num_burst_with_length(stat, i), 1);
          else
            check_equal(get_num_burst_with_length(stat, i), 0);
          end if;
        end loop;

      elsif run("test copy") then
        stat := new_axi_statistics;
        add_burst_length(stat, 7);
        stat2 := copy(stat);
        add_burst_length(stat, 17);
        check_equal(num_bursts(stat), 2);
        clear(stat);
        check_equal(num_bursts(stat2), 1);
        check_equal(get_num_burst_with_length(stat2, 7), 1);
        check_equal(get_num_burst_with_length(stat2, 17), 0);

      elsif run("test clear") then
        stat := new_axi_statistics;
        add_burst_length(stat, 7);
        add_burst_length(stat, 17);
        clear(stat);
        check_equal(num_bursts(stat), 0);
        check_equal(get_num_burst_with_length(stat, 7), 0);
        check_equal(get_num_burst_with_length(stat, 17), 0);
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;
end;
