
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.stream_full_duplex_pkg.all;
use work.spi_pkg.all;

entity tb_spi is
  generic (runner_cfg: string);
end entity tb_spi;

architecture testbench of tb_spi is
  constant master_spi: spi_master_t := new_spi_master(clk_period => 20 ns);
  constant master_spi_stream: stream_full_duplex_t := as_stream(master_spi);

  constant slave_spi: spi_slave_t := new_spi_slave(data_length => 32);
  constant slave_spi_stream: stream_full_duplex_t := as_stream(slave_spi);

  signal spi_ss_n: std_logic;
  signal spi_sclk: std_logic;
  signal spi_miso: std_logic;
  signal spi_mosi: std_logic;

begin

  main: process
    variable msg: msg_t;
    variable s2m_data, m2s_data: std_logic_vector(31 downto 0);

  begin
    test_runner_setup(runner, runner_cfg);
    -- Displays debug messages
    show_all(display_handler);

    if run("Test single full duplex transaction.") then
      wait for 25 ns;

      -- Master transmits x"00CAFF0D" to the slave
      push_stream(net, master_spi_stream, x"00CAFF0D");
      -- Slave transmits x"00FF00FF" to the master
      push_stream(net, slave_spi_stream, x"00FF00FF");

      -- Start the transaction
      msg := new_msg(stream_trigger_msg);
      send(net, master_spi.p_actor, msg);

      -- Slave receives x"00CAFF0D" in m2s_data
      pop_stream(net, slave_spi_stream, m2s_data);
      -- Master receives x"00FF00FF" in s2m_data
      pop_stream(net, master_spi_stream, s2m_data);

      check_equal(m2s_data, std_logic_vector'(x"00CAFF0D"), "pop stream m2s_data");
      check_equal(s2m_data, std_logic_vector'(x"00FF00FF"), "pop stream m2s_data");

    elsif run("Test multiple full duplex transactions.") then
      wait for 25 ns;

      for i in 0 to 7 loop
        push_stream(net, master_spi_stream, std_logic_vector(to_unsigned(i, 32)));
        push_stream(net, slave_spi_stream, std_logic_vector(to_unsigned(8+i, 32)));

        -- Start the transaction
        msg := new_msg(stream_trigger_msg);
        send(net, master_spi.p_actor, msg);

        pop_stream(net, slave_spi_stream, m2s_data);
        pop_stream(net, master_spi_stream, s2m_data);

        check_equal(m2s_data, std_logic_vector(to_unsigned(i, 32)), "pop stream m2s_data.");
        check_equal(s2m_data, std_logic_vector(to_unsigned(i+8, 32)), "pop stream s2m_data.");
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 20 ms);

  spi_master_inst: entity work.spi_master
    generic map
    (
      spi => master_spi,
      cpol => '0',
      cpha => '0'
    )
    port map
    (
      ss_n => spi_ss_n,
      sclk => spi_sclk,
      mosi => spi_mosi,
      miso => spi_miso
    );

  spi_slave_inst: entity work.spi_slave
    generic map
    (
      spi => slave_spi,
      cpol => '0',
      cpha => '0'
    )
    port map
    (
      ss_n => spi_ss_n,
      sclk => spi_sclk,
      mosi => spi_mosi,
      miso => spi_miso
    );
end architecture testbench;
