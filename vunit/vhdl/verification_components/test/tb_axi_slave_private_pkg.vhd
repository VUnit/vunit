-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.vc_context;
use work.axi_pkg.all;
use work.axi_slave_private_pkg.all;

entity tb_axi_slave_private_pkg is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_axi_slave_private_pkg is
  signal init : boolean := false;
  shared variable axi_slave : axi_slave_private_t;
begin
  main : process
    variable data : std_logic_vector(127 downto 0);

    variable axid : std_logic_vector(3 downto 0);
    constant max_id : natural := 2**axid'length-1;
    variable axaddr : std_logic_vector(31 downto 0);
    variable axlen : axi4_len_t;
    variable axsize : axi4_size_t;
    variable axburst : axi_burst_type_t;

    variable burst : axi_burst_t;
    variable logger : logger_t := get_logger("axi_slave");
    constant axi_public_slave : axi_slave_t := new_axi_slave(memory => new_memory,
                                                             logger => logger);
    variable stat : axi_statistics_t;

    procedure slave_init(axi_slave_type : axi_slave_type_t) is
    begin
      axi_slave.init(axi_public_slave,
                     axi_slave_type,
                     max_id,
                     data);
    end;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test create_burst updates statistics") then
      slave_init(read_slave);
      init <= true;
      wait for 0 ns;
      axid := x"2";
      axaddr := x"00100000";
      axlen := x"ff";
      axsize := "100";
      axburst := axi_burst_type_fixed;

      get_statistics(net, axi_public_slave, stat);
      check_equal(get_num_burst_with_length(stat, 256), 0,
                  "No burst before create");
      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_equal(get_num_burst_with_length(stat, 256), 0,
                  "Statistics was copied before create");

      get_statistics(net, axi_public_slave, stat);
      check_equal(get_num_burst_with_length(stat, 256), 1,
                  "Newly read statistics has one entry");

      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);

      get_statistics(net, axi_public_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, 256), 2,
                  "One more burst");

      check_equal(min_burst_length(stat), 256,
                  "min_burst_length");

      check_equal(max_burst_length(stat), 256,
                  "max_burst_length");

      get_statistics(net, axi_public_slave, stat);

      check_equal(get_num_burst_with_length(stat, 256), 0,
                  "Cleared");

    elsif run("test create_burst read debug messages") then
      slave_init(read_slave);
      mock(logger, debug);
      axid := x"2";
      axaddr := x"00100000";
      axlen := x"ff";
      axsize := "100";
      axburst := axi_burst_type_fixed;

      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_only_log(logger,
                     "Got read burst #0 for id 2" & LF &
                     "arid    = 0x2" & LF &
                     "araddr  = 0x00100000" & LF &
                     "arlen   = 255" & LF &
                     "arsize  = 4" & LF &
                     "arburst = fixed (00)",
                     debug);

      axburst := axi_burst_type_incr;
      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_only_log(logger,
                     "Got read burst #1 for id 2" & LF &
                     "arid    = 0x2" & LF &
                     "araddr  = 0x00100000" & LF &
                     "arlen   = 255" & LF &
                     "arsize  = 4" & LF &
                     "arburst = incr (01)",
                     debug);

      -- Each id has a separate burst index
      axid := x"0";
      axburst := axi_burst_type_incr;
      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_only_log(logger,
                     "Got read burst #0 for id 0" & LF &
                     "arid    = 0x0" & LF &
                     "araddr  = 0x00100000" & LF &
                     "arlen   = 255" & LF &
                     "arsize  = 4" & LF &
                     "arburst = incr (01)",
                     debug);

      unmock(logger);

    elsif run("test create_burst write debug messages") then
      slave_init(write_slave);

      mock(logger, debug);
      axid := x"2";
      axaddr := x"00100000";
      axlen := x"ff";
      axsize := "100";
      axburst := axi_burst_type_fixed;

      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_only_log(logger,
                     "Got write burst #0 for id 2" & LF &
                     "awid    = 0x2" & LF &
                     "awaddr  = 0x00100000" & LF &
                     "awlen   = 255" & LF &
                     "awsize  = 4" & LF &
                     "awburst = fixed (00)",
                     debug);

      axburst := axi_burst_type_incr;
      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_only_log(logger,
                     "Got write burst #1 for id 2" & LF &
                     "awid    = 0x2" & LF &
                     "awaddr  = 0x00100000" & LF &
                     "awlen   = 255" & LF &
                     "awsize  = 4" & LF &
                     "awburst = incr (01)",
                     debug);

      -- Each id has a separate burst index
      axid := x"0";
      axburst := axi_burst_type_incr;
      burst := axi_slave.create_burst(axid, axaddr, axlen, axsize, axburst);
      check_only_log(logger,
                     "Got write burst #0 for id 0" & LF &
                     "awid    = 0x0" & LF &
                     "awaddr  = 0x00100000" & LF &
                     "awlen   = 255" & LF &
                     "awsize  = 4" & LF &
                     "awburst = incr (01)",
                     debug);

      unmock(logger);

    elsif run("test pop_resp debug messages") then
      slave_init(write_slave);

      mock(logger, debug);

      burst.index := 77;
      burst.id := 13;
      axi_slave.push_resp(burst);

      check_no_log;

      burst := axi_slave.pop_resp;

      check_only_log(logger, "Providing write response for burst #77 for id 13", debug);

      unmock(logger);

    elsif run("test pop_burst write slave debug messages") then
      slave_init(write_slave);

      burst.index := 77;
      burst.id := 13;
      axi_slave.push_resp(burst);
      axi_slave.push_burst(burst);
      mock(logger, debug);
      burst := axi_slave.pop_burst;
      check_only_log(logger, "Start accepting data for write burst #77 for id 13", debug);
      unmock(logger);

    elsif run("test pop_burst read slave debug messages") then
      slave_init(read_slave);

      burst.index := 77;
      burst.id := 13;
      axi_slave.push_resp(burst);
      axi_slave.push_burst(burst);
      mock(logger, debug);
      burst := axi_slave.pop_burst;
      check_only_log(logger, "Start providing data for read burst #77 for id 13", debug);
      unmock(logger);

    elsif run("test finish_burst read slave debug messages") then
      slave_init(read_slave);
      mock(logger, debug);

      burst.index := 77;
      burst.id := 13;
      axi_slave.push_resp(burst);
      axi_slave.finish_burst(burst);
      check_only_log(logger, "Providing last data for read burst #77 for id 13", debug);

      unmock(logger);

    elsif run("test finish_burst write slave debug messages") then
      slave_init(write_slave);
      mock(logger, debug);

      burst.index := 77;
      burst.id := 13;
      axi_slave.push_resp(burst);
      axi_slave.finish_burst(burst);
      check_only_log(logger, "Accepted last data for write burst #77 for id 13", debug);

      unmock(logger);
    end if;
    test_runner_cleanup(runner);
  end process;

  slave_main : process
  begin
    wait until init;
    main_loop(axi_slave, net);
  end process;
end architecture;
