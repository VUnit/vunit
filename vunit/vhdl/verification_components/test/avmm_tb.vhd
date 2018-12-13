
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
use vunit_lib.sync_pkg.all;

use work.stream_full_duplex_pkg.all;
use work.avmm_pkg.all;

entity tb_avmm is
  generic (runner_cfg: string);
end entity tb_avmm;

architecture testbench of tb_avmm is
  constant master_avmm: avmm_master_t := new_avmm_master;
  constant master_avmm_stream: stream_full_duplex_t := as_stream(master_avmm);

  constant slave_avmm: avmm_slave_t := new_avmm_slave;
  constant slave_avmm_stream: stream_full_duplex_t := as_stream(slave_avmm);

  signal clk: std_logic := '0';
  signal rstn: std_logic;
  signal read: std_logic;
  signal write: std_logic;
  signal address: std_logic_vector(7 downto 0);
  signal writedata: std_logic_vector(31 downto 0);
  signal waitrequest: std_logic;
  signal readdata: std_logic_vector(31 downto 0);
  signal readdatavalid: std_logic;

begin

  main: process
    variable reply_msg, s2m_msg, m2s_msg: msg_t;
    variable v_read, v_write: std_logic;
    variable v_address: integer;
    variable v_writedata: std_logic_vector(31 downto 0);
    constant slv_00caff0d: std_logic_vector(31 downto 0) := x"00CAFF0D";
    variable v_readdata: std_logic_vector(31 downto 0);
    constant slv_caff0d00: std_logic_vector(31 downto 0) := x"CAFF0D00";
    variable reference: stream_reference_t;
  begin
    test_runner_setup(runner, runner_cfg);
    show_all(display_handler);

    if run("Test single full duplex, 2 transactions.") then
      wait for 21 ns;

      -- Master transmits write message
      push_stream
      (
        net => net,
        stream => master_avmm_stream,
        read => '0',
        write => '1',
        address => 0,
        writedata => x"00CAFF0D"
      );

      -- Master transmits read message
      push_stream
      (
        net => net,
        stream => master_avmm_stream,
        read => '1',
        write => '0',
        address => 4,
        writedata => x"CAFF0D00"
      );

      -- Slave transmits 2 data messages
      push_stream
      (
        net => net,
        stream => slave_avmm_stream,
        readdata => x"CAFF0D00"
      );
      push_stream
      (
        net => net,
        stream => slave_avmm_stream,
        readdata => x"00CAFF0D"
      );

      -- Check that the slave has received the master's messages.
      check_avmm_m2s_msg
      (
        net => net,
        slave_avmm => slave_avmm,
        ref_read => '0',
        ref_write => '1',
        ref_address => 0,
        ref_writedata => x"00CAFF0D"
      );

      check_avmm_m2s_msg
      (
        net => net,
        slave_avmm => slave_avmm,
        ref_read => '1',
        ref_write => '0',
        ref_address => 4,
        ref_writedata => x"CAFF0D00"
      );

      -- Check that the master has received the slave's messages.
      check_avmm_s2m_msg
      (
        net => net,
        master_avmm => master_avmm,
        ref_readdata => x"CAFF0D00"
      );

      check_avmm_s2m_msg
      (
        net => net,
        master_avmm => master_avmm,
        ref_readdata => x"00CAFF0D"
      );

    elsif run("Test multiple full duplex transactions.") then
      for i in 0 to 255 loop
        push_stream
        (
          net => net,
          stream => master_avmm_stream,
          read => '0',
          write => '1',
          address => i,
          writedata => std_logic_vector(to_unsigned(i, 32))
        );

        push_stream
        (
          net => net,
          stream => slave_avmm_stream,
          readdata => std_logic_vector(to_unsigned(255-i, 32))
        );

        check_avmm_m2s_msg
        (
          net => net,
          slave_avmm => slave_avmm,
          ref_read => '0',
          ref_write => '1',
          ref_address => i,
          ref_writedata => std_logic_vector(to_unsigned(i, 32))
        );

        -- Check that the master has received the slave's messages.
        check_avmm_s2m_msg
        (
          net => net,
          master_avmm => master_avmm,
          ref_readdata => std_logic_vector(to_unsigned(255-i, 32))
        );
      end loop;

      wait for 21 ns;
    end if;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 2 ms);

  clk <= not clk after 10 ns;
  rstn <= '0', '1' after 25 ns;

  avmm_master_inst: entity work.avmm_master
    generic map
    (
      avmm => master_avmm
    )
    port map
    (
      clk => clk,
      rstn => rstn,
      read =>read,
      write => write,
      address => address,
      writedata => writedata,
      waitrequest => waitrequest,
      readdata => readdata,
      readdatavalid => readdatavalid
    );

  avmm_slave_inst: entity work.avmm_slave
    generic map
    (
      avmm => slave_avmm
    )
    port map
    (
      clk => clk,
      rstn => rstn,
      read =>read,
      write => write,
      address => address,
      writedata => writedata,
      waitrequest => waitrequest,
      readdata => readdata,
      readdatavalid => readdatavalid
    );
end architecture testbench;
