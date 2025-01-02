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
use work.avalon_pkg.all;

entity tb_avalon_slave is
  generic (
    runner_cfg : string;
    encoded_tb_cfg : string
  );
end entity;

architecture a of tb_avalon_slave is

  type tb_cfg_t is record
    data_width : positive;
    address_width : positive;
    burstcount_width : positive;
    num_cycles : positive;
    readdatavalid_prob : real;
    waitrequest_prob : real;
  end record tb_cfg_t;

  impure function decode(encoded_tb_cfg : string) return tb_cfg_t is
  begin
    return (data_width => positive'value(get(encoded_tb_cfg, "data_width")),
            address_width => 32,
            burstcount_width => 8,
            num_cycles => positive'value(get(encoded_tb_cfg, "num_cycles")),
            readdatavalid_prob => real'value(get(encoded_tb_cfg, "readdatavalid_prob")),
            waitrequest_prob => real'value(get(encoded_tb_cfg, "waitrequest_prob")));
  end function decode;

  constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

  signal clk    : std_logic := '0';
  signal address    : std_logic_vector(tb_cfg.address_width-1 downto 0) := (others => '0');
  signal writedata  : std_logic_vector(tb_cfg.data_width-1 downto 0) := (others => '0');
  signal readdata  : std_logic_vector(tb_cfg.data_width-1 downto 0) := (others => '0');
  signal byteenable : std_logic_vector(tb_cfg.data_width/8 -1 downto 0) := (others => '1');
  signal burstcount : std_logic_vector(tb_cfg.burstcount_width -1 downto 0) := (others => '0');
  signal write   : std_logic := '0';
  signal read  : std_logic := '0';
  signal waitrequest    : std_logic := '0';
  signal readdatavalid : std_logic := '0';


  constant tb_logger : logger_t := get_logger("tb");

  signal rd_ack_cnt    : natural range 0 to tb_cfg.num_cycles;

  constant memory : memory_t := new_memory;
  constant buf : buffer_t := allocate(memory, tb_cfg.num_cycles * byteenable'length);
  constant avalon_slave : avalon_slave_t :=
      new_avalon_slave(memory => memory,
        name => "avmm_vc",
        readdatavalid_high_probability => tb_cfg.readdatavalid_prob,
        waitrequest_high_probability => tb_cfg.waitrequest_prob
      );
begin

  main_stim : process
  begin
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);
    show(tb_logger, display_handler, trace);
    show(default_logger, display_handler, trace);
    show(com_logger, display_handler, trace);
    burstcount <= std_logic_vector(to_unsigned(1, burstcount'length));
    wait until rising_edge(clk);


    if run("wr block rd block") then
      info(tb_logger, "Writing...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        write <= '1';
        address <= std_logic_vector(to_unsigned(i*(byteenable'length), address'length));
        writedata <= std_logic_vector(to_unsigned(i, writedata'length));
        wait until rising_edge(clk) and waitrequest = '0';
      end loop;
      write <= '0';

      wait until rising_edge(clk);

      info(tb_logger, "Reading...");
      for i in 0 to tb_cfg.num_cycles-1 loop
        read <= '1';
        address <= std_logic_vector(to_unsigned(i*(byteenable'length), address'length));
        wait until rising_edge(clk) and waitrequest = '0';
      end loop;
      read <= '0';

      wait until rising_edge(clk) and rd_ack_cnt = tb_cfg.num_cycles-1;

    elsif run("burst wr block rd block") then
      info(tb_logger, "Writing...");
      address <= (others => 'U');
      burstcount(0) <= '1';

      for i in 0 to tb_cfg.num_cycles-1 loop
        if i = 0 then
          address <= std_logic_vector(to_unsigned(0, address'length));
          burstcount <= std_logic_vector(to_unsigned(tb_cfg.num_cycles, burstcount'length));
        end if;
        write <= '1';
        writedata <= std_logic_vector(to_unsigned(i, writedata'length));
        wait until rising_edge(clk) and waitrequest = '0';
      end loop;
      write <= '0';
      address <= (others => 'U');
      burstcount <= (others => 'U');
      writedata <= (others => 'U');

      wait until rising_edge(clk);

      info(tb_logger, "Reading...");
      wait until rising_edge(clk);
      read <= '1';
      burstcount <= std_logic_vector(to_unsigned(tb_cfg.num_cycles, burstcount'length));
      address <= std_logic_vector(to_unsigned(0, address'length));
      wait until rising_edge(clk) and waitrequest = '0';
      read <= '0';

      wait until rising_edge(clk) and rd_ack_cnt = tb_cfg.num_cycles-1;

    elsif run("byte enable") then
      info(tb_logger, "Writing with byte enable...");
      address <= (others => 'U');
      burstcount(0) <= '1';

      for i in 0 to tb_cfg.num_cycles-1 loop
        if i = 0 then
          address <= std_logic_vector(to_unsigned(0, address'length));
          burstcount <= std_logic_vector(to_unsigned(tb_cfg.num_cycles, burstcount'length));
        end if;
        -- set byte enable for last word
        if i=tb_cfg.num_cycles-1 then
          byteenable <= std_logic_vector(to_unsigned(1,byteenable'length));
        end if;
        write <= '1';
        writedata <= std_logic_vector(to_unsigned(256+i, writedata'length));
        wait until rising_edge(clk) and waitrequest = '0';
      end loop;
      write <= '0';

      wait until rising_edge(clk);
      info(tb_logger, "Reading with byte enable...");
      wait until rising_edge(clk);
      read <= '1';
      burstcount <= std_logic_vector(to_unsigned(tb_cfg.num_cycles, burstcount'length));
      address <= std_logic_vector(to_unsigned(0, address'length));
      wait until rising_edge(clk) and waitrequest = '0';
      read <= '0';

      wait until rising_edge(clk) and rd_ack_cnt = tb_cfg.num_cycles-1;
    end if;

    wait for 50 ns;
    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 100 us);

  rd_ack: process
  begin
    wait until rising_edge(clk) and readdatavalid = '1';
    if active_test_case = "byte enable" then
      if rd_ack_cnt = tb_cfg.num_cycles-1 then
        check_equal(readdata, std_logic_vector(to_unsigned(rd_ack_cnt,readdata'length)), "readdata");
      else
        check_equal(readdata, std_logic_vector(to_unsigned(256+rd_ack_cnt,readdata'length)), "readdata");
      end if;
    else
      check_equal(readdata, std_logic_vector(to_unsigned(rd_ack_cnt,readdata'length)), "readdata");
    end if;
    rd_ack_cnt <= rd_ack_cnt +1;
  end process;

  dut_slave : entity work.avalon_slave
    generic map (
      avalon_slave => avalon_slave
    )
    port map (
      clk   => clk,
      address   => address,
      byteenable => byteenable,
      burstcount => burstcount,
      write => write,
      writedata => writedata,
      read => read,
      readdata => readdata,
      readdatavalid => readdatavalid,
      waitrequest => waitrequest
    );

  clk <= not clk after 5 ns;

end architecture;
