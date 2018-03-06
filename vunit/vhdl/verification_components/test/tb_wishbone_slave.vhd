-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;

entity tb_wishbone_slave is
  generic (
    runner_cfg : string;
    dat_width    : positive := 8;
    adr_width    : positive := 4;
    num_cycles : positive := 1;
    max_ack_dly : natural := 0;
    rand_stall  : boolean := false
  );
end entity;

architecture a of tb_wishbone_slave is
  signal clk    : std_logic := '0';
  signal adr    : std_logic_vector(adr_width-1 downto 0) := (others => '0');
  signal dat_i  : std_logic_vector(dat_width-1 downto 0) := (others => '0');
  signal dat_o  : std_logic_vector(dat_width-1 downto 0) := (others => '0');
  signal sel   : std_logic_vector(dat_width/8 -1 downto 0) := (others => '1');
  signal cyc   : std_logic := '0';
  signal stb   : std_logic := '0';
  signal we    : std_logic := '0';
  signal stall : std_logic := '0';
  signal ack   : std_logic := '0';


  constant tb_logger : logger_t := get_logger("tb");

  signal wr_ack_cnt    : natural range 0 to num_cycles;
  signal rd_ack_cnt    : natural range 0 to num_cycles;
begin

  main_stim : process
    variable tmp : std_logic_vector(dat_i'range);
    variable value : std_logic_vector(dat_i'range) := (others => '1');
  begin
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);
    show(tb_logger, display_handler, verbose);
    show(default_logger, display_handler, verbose);
    show(com_logger, display_handler, verbose);
    wait until rising_edge(clk);


    if run("wr block rd block") then
      info(tb_logger, "Writing...");
      for i in 0 to num_cycles-1 loop
        cyc <= '1';
        stb <= '1';
        we  <= '1';
        adr <= std_logic_vector(to_unsigned(i*(sel'length), adr'length));
        dat_i <= std_logic_vector(to_unsigned(i, dat_i'length));
        wait until rising_edge(clk) and stall = '0';
      end loop;
      stb <= '0';
      wait until wr_ack_cnt = num_cycles;
      cyc <= '0';

      wait until rising_edge(clk);

      info(tb_logger, "Reading...");
      for i in 0 to num_cycles-1 loop
        cyc <= '1';
        stb <= '1';
        we  <= '0';
        adr <= std_logic_vector(to_unsigned(i*(sel'length), adr'length));
        wait until rising_edge(clk) and stall = '0';
      end loop;
      stb <= '0';
      wait until rising_edge(clk) and rd_ack_cnt = num_cycles-1;
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
      max_ack_dly => max_ack_dly,
      rand_stall => rand_stall
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
