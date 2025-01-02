-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
use work.memory_pkg.all;
use work.wishbone_pkg.all;
use work.bus_master_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_wishbone_master is
  generic (
    runner_cfg : string;
    encoded_tb_cfg : string
  );
end entity;

architecture a of tb_wishbone_master is

  type tb_cfg_t is record
    dat_width : positive;
    adr_width : positive;
    num_cycles : positive;
    strobe_prob : real;
    ack_prob : real;
    stall_prob : real;
    slave_inst : boolean;
  end record tb_cfg_t;

  impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
  begin
    return (dat_width => positive'value(get(encoded_tb_cfg, "dat_width")),
            adr_width => positive'value(get(encoded_tb_cfg, "adr_width")),
            num_cycles => positive'value(get(encoded_tb_cfg, "num_cycles")),
            strobe_prob => real'value(get(encoded_tb_cfg, "strobe_prob")),
            ack_prob => real'value(get(encoded_tb_cfg, "ack_prob")),
            stall_prob => real'value(get(encoded_tb_cfg, "stall_prob")),
            slave_inst => boolean'value(get(encoded_tb_cfg, "slave_inst")));
  end function decode;

  constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

  signal clk    : std_logic := '0';
  signal adr    : std_logic_vector(tb_cfg.adr_width-1 downto 0);
  signal dat_i  : std_logic_vector(tb_cfg.dat_width-1 downto 0);
  signal dat_o  : std_logic_vector(tb_cfg.dat_width-1 downto 0);
  signal sel   : std_logic_vector(tb_cfg.dat_width/8 -1 downto 0);
  signal cyc   : std_logic := '0';
  signal stb   : std_logic := '0';
  signal we    : std_logic := '0';
  signal stall : std_logic := '0';
  signal ack   : std_logic := '0';

  constant master_logger : logger_t := get_logger("master");
  constant tb_logger : logger_t := get_logger("tb");
  constant bus_handle : bus_master_t := new_bus(data_length => tb_cfg.dat_width,
      address_length => tb_cfg.adr_width, logger => master_logger);

  constant memory : memory_t := new_memory;
  constant buf : buffer_t := allocate(memory, tb_cfg.num_cycles * sel'length);
  constant wishbone_slave : wishbone_slave_t := new_wishbone_slave(
    memory => memory,
    ack_high_probability => tb_cfg.ack_prob,
    stall_high_probability => tb_cfg.stall_prob
  );

begin

  main_stim : process
    variable tmp : std_logic_vector(dat_i'range);
    variable chk_time : time;
    variable value : std_logic_vector(dat_i'range) := (others => '1');
    variable bus_rd_ref1 : bus_reference_t;
    variable bus_rd_ref2 : bus_reference_t;
    type bus_reference_arr_t is array (0 to tb_cfg.num_cycles-1) of bus_reference_t;
    variable rd_ref : bus_reference_arr_t;
  begin
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);
    show(tb_logger, display_handler, trace);
    show(default_logger, display_handler, trace);
    show(master_logger, display_handler, trace);
    show(com_logger, display_handler, trace);

    wait until rising_edge(clk);

    if run("wr single rd single") then
      info(tb_logger, "Writing...");
      write_bus(net, bus_handle, 0, value);
      wait until ack = '1' and rising_edge(clk);
      wait until rising_edge(clk);
      wait for 100 ns;
      info(tb_logger, "Reading...");
      read_bus(net, bus_handle, 0, tmp);
      check_equal(tmp, value, "read data");
--    elsif run("wr block") then
--      -- TODO not sure if is allowed to toggle signal we during
--      -- wishbone single cycle
--      write_bus(net, bus_handle, 0, value);
--      read_bus(net, bus_handle, 0, tmp);
--      check_equal(tmp, value, "read data");
    elsif run("wr block rd single") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        write_bus(net, bus_handle, i*(sel'length),
            std_logic_vector(to_unsigned(i, dat_i'length)));
      end loop;

      info(tb_logger, "Reading...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        read_bus(net, bus_handle, i*(sel'length), tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
      end loop;

    elsif run("wr block rd block") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        write_bus(net, bus_handle, i*(sel'length),
            std_logic_vector(to_unsigned(i, dat_i'length)));
      end loop;

      info(tb_logger, "Reading...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        read_bus(net, bus_handle, i*(sel'length), rd_ref(i));
      end loop;

      info(tb_logger, "Get reads by references...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        await_read_bus_reply(net, rd_ref(i), tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(i, dat_i'length)), "read data");
      end loop;

    elsif run ("wait for idle") then
      for i in 0 to 5 loop
        chk_time := now;
        read_bus(net, bus_handle, 0, bus_rd_ref1);
        write_bus(net, bus_handle, 0, value);
        read_bus(net, bus_handle, 0, bus_rd_ref2);
        check_equal(chk_time, now, "tb concept broken, command issueing takes time");
        wait_until_idle(net, bus_handle);
        check_equal(cyc, '0', "bus not idle");
        info(tb_logger, "Waited for " & to_string(now-chk_time));
        chk_time := now;
        await_read_bus_reply(net, bus_rd_ref1, tmp);
        await_read_bus_reply(net, bus_rd_ref2, tmp);
        check_equal(chk_time, now, "reading was not done");
        check_equal(tmp, value, "read value incorrect");
        wait for 20 ns;
      end loop;

    elsif run("slave comb ack") then
      write_bus(net, bus_handle, 0, value);
      wait until ack = '1' and rising_edge(clk);
      wait for 20 ns;

    end if;

    info(tb_logger, "Done, quit...");
    wait for 50 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);

  dut : entity work.wishbone_master
    generic map (
      bus_handle => bus_handle,
      strobe_high_probability => tb_cfg.strobe_prob)
    port map (
      clk   => clk,
      adr   => adr,
      dat_i => dat_i,
      dat_o => dat_o,
      sel   => sel,
      cyc   => cyc,
      stb   => stb,
      we    => we,
      stall => stall,
      ack   => ack
    );

  slave_gen : if tb_cfg.slave_inst generate
    dut_slave : entity work.wishbone_slave
      generic map (
        wishbone_slave => wishbone_slave
      )
      port map (
        clk   => clk,
        adr   => adr,
        dat_i => dat_o,
        dat_o => dat_i,
        sel   => sel,
        cyc   => cyc,
        stb   => stb,
        we    => we,
        stall => stall,
        ack   => ack
      );
  else generate
    signal wr_r : std_ulogic;
  begin
    proc : process(clk) is begin
      if rising_edge(clk) then
        wr_r <= we and cyc and stb;
      end if;
    end process;
    ack <= wr_r and not stall and cyc;
    stall <= not wr_r;
  end generate;

  clk <= not clk after 5 ns;

end architecture;
