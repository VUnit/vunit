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

entity tb_wishbone_slave is
  generic (
    runner_cfg : string;
    encoded_tb_cfg : string
  );
end entity;

architecture a of tb_wishbone_slave is

  type tb_cfg_t is record
    dat_width : positive;
    adr_width : positive;
    num_cycles : positive;
    ack_prob : real;
    stall_prob : real;
  end record tb_cfg_t;

  impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
  begin
    return (dat_width => positive'value(get(encoded_tb_cfg, "dat_width")),
            adr_width => positive'value(get(encoded_tb_cfg, "adr_width")),
            num_cycles => positive'value(get(encoded_tb_cfg, "num_cycles")),
            ack_prob => real'value(get(encoded_tb_cfg, "ack_prob")),
            stall_prob => real'value(get(encoded_tb_cfg, "stall_prob")));
  end function decode;

  constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

  signal clk    : std_logic := '0';
  signal adr    : std_logic_vector(tb_cfg.adr_width-1 downto 0) := (others => '0');
  signal dat_i  : std_logic_vector(tb_cfg.dat_width-1 downto 0) := (others => '0');
  signal dat_o  : std_logic_vector(tb_cfg.dat_width-1 downto 0) := (others => '0');
  signal sel   : std_logic_vector(tb_cfg.dat_width/8 -1 downto 0) := (others => '1');
  signal cyc   : std_logic := '0';
  signal stb   : std_logic := '0';
  signal we    : std_logic := '0';
  signal stall : std_logic := '0';
  signal ack   : std_logic := '0';


  constant tb_logger : logger_t := get_logger("tb");

  signal wr_ack_cnt    : natural range 0 to tb_cfg.num_cycles;
  signal rd_ack_cnt    : natural range 0 to tb_cfg.num_cycles;

  constant memory : memory_t := new_memory;
  constant buf : buffer_t := allocate(memory, tb_cfg.num_cycles * sel'length);
  constant wishbone_slave : wishbone_slave_t :=
      new_wishbone_slave(memory => memory,
        ack_high_probability => tb_cfg.ack_prob,
        stall_high_probability => tb_cfg.stall_prob
      );
begin

  main_stim : process
  begin
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);
    show(tb_logger, display_handler, trace);
    show(default_logger, display_handler, trace);
    show(com_logger, display_handler, trace);
    wait until rising_edge(clk);


    if run("wr block rd block") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        cyc <= '1';
        stb <= '1';
        we  <= '1';
        adr <= std_logic_vector(to_unsigned(i*(sel'length), adr'length));
        dat_i <= std_logic_vector(to_unsigned(i, dat_i'length));
        wait until rising_edge(clk) and stall = '0';
      end loop;
      stb <= '0';
      wait until wr_ack_cnt = tb_cfg.num_cycles;
      cyc <= '0';

      wait until rising_edge(clk);

      info(tb_logger, "Reading...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        cyc <= '1';
        stb <= '1';
        we  <= '0';
        adr <= std_logic_vector(to_unsigned(i*(sel'length), adr'length));
        wait until rising_edge(clk) and stall = '0';
      end loop;
      stb <= '0';
      wait until rising_edge(clk) and rd_ack_cnt = tb_cfg.num_cycles-1;
      cyc <= '0';
    end if;

    wait for 50 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);

  wr_ack: process
  begin
    wait until rising_edge(clk) and ack = '1' and we = '1';
    wr_ack_cnt <= wr_ack_cnt +1;
  end process;

  rd_ack: process
  begin
    wait until rising_edge(clk) and ack = '1' and we = '0';
    check_equal(dat_o, std_logic_vector(to_unsigned(rd_ack_cnt,
          dat_o'length)), "dat_o");
    rd_ack_cnt <= rd_ack_cnt +1;
  end process;

  dut_slave : entity work.wishbone_slave
    generic map (
      wishbone_slave => wishbone_slave
    )
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

  clk <= not clk after 5 ns;

end architecture;
