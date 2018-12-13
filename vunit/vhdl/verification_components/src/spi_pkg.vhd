-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Sebastiaan Jacobs basfriends@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;
use vunit_lib.queue_pkg.all;

use work.stream_full_duplex_pkg.all;

package spi_pkg
is
  type spi_master_t is record
    p_actor: actor_t;
    p_clk_period: time;
    p_idle_state: std_logic;
    p_data_length: positive;
  end record;

  type spi_slave_t is record
    p_actor: actor_t;
    p_idle_state: std_logic;
    p_data_length: positive;
  end record;

  constant default_clk_period: time := 40 ns;
  constant default_idle_state: std_logic := 'Z';
  constant default_data_length: positive := 32;
  impure function new_spi_master
  (
    clk_period: time := default_clk_period;
    idle_state: std_logic := default_idle_state;
    data_length: positive := default_data_length
  ) return spi_master_t;
  impure function new_spi_slave
  (
    idle_state: std_logic := default_idle_state;
    data_length: positive := default_data_length
  ) return spi_slave_t;

  impure function as_stream
  (
    spi_master: spi_master_t
  ) return stream_full_duplex_t;
  impure function as_stream
  (
    spi_slave: spi_slave_t
  ) return stream_full_duplex_t;

  impure function as_sync
  (
    spi_master: spi_master_t
  ) return sync_handle_t;
  impure function as_sync
  (
    spi_slave: spi_slave_t
  ) return sync_handle_t;

  procedure spi_master_transaction
  (
    constant spi: in spi_master_t;

    constant cpol: in std_logic;
    constant cpha: in std_logic;

    variable m2s_data: in std_logic_vector;
    variable s2m_data: out std_logic_vector;

    signal ss_n: out std_logic;
    signal sclk: out std_logic;
    signal mosi: out std_logic;
    signal miso: in std_logic
  );

  procedure spi_slave_transaction
  (
    constant cpol: in std_logic;
    constant cpha: in std_logic;

    variable s2m_data: in std_logic_vector;
    variable m2s_data: out std_logic_vector;

    signal ss_n: in std_logic;
    signal sclk: in std_logic;
    signal mosi: in std_logic;
    signal miso: out std_logic
  );

  procedure nudge
  (
    signal irq: out std_logic
  );

  constant spi_m2s_data_msg: msg_type_t := new_msg_type("SPI M2S data message");
  constant spi_s2m_data_msg: msg_type_t := new_msg_type("SPI S2M data message");
end package;

package body spi_pkg
is

  impure function new_spi_master
  (
    clk_period: time := default_clk_period;
    idle_state: std_logic := default_idle_state;
    data_length: positive := default_data_length
  ) return spi_master_t
  is
  begin
    return
    (
      p_actor => new_actor,
      p_clk_period => clk_period,
      p_idle_state => idle_state,
      p_data_length => data_length
    );
  end;

  impure function new_spi_slave
  (
    idle_state: std_logic := default_idle_state;
    data_length: positive := default_data_length
  ) return spi_slave_t
  is
  begin
    return
    (
      p_actor => new_actor,
      p_idle_state => idle_state,
      p_data_length => data_length
    );
  end;

  impure function as_stream
  (
    spi_master: spi_master_t
  ) return stream_full_duplex_t
  is
  begin
    return stream_full_duplex_t'(p_actor => spi_master.p_actor);
  end;

  impure function as_stream
  (
    spi_slave: spi_slave_t
  ) return stream_full_duplex_t
  is
  begin
    return stream_full_duplex_t'(p_actor => spi_slave.p_actor);
  end;

  impure function as_sync
  (
    spi_master: spi_master_t
  ) return sync_handle_t
  is
  begin
    return spi_master.p_actor;
  end;

  impure function as_sync
  (
    spi_slave: spi_slave_t
  ) return sync_handle_t
  is
  begin
    return spi_slave.p_actor;
  end;

  procedure spi_master_transaction
  (
    constant spi: in spi_master_t;
    constant cpol: in std_logic;
    constant cpha: in std_logic;

    variable m2s_data: in std_logic_vector;
    variable s2m_data: out std_logic_vector;

    signal ss_n: out std_logic;
    signal sclk: out std_logic;
    signal mosi: out std_logic;
    signal miso: in std_logic
  )
  is
    constant half_clk_period: time := spi.p_clk_period / 2;
  begin
    debug("Sending " & to_string(m2s_data));

    ss_n <= '0';

    if cpol = '0' and cpha = '0' then

      for data_index in m2s_data'length-1 downto 0 loop
        sclk <= '0';
        mosi <= m2s_data(data_index);
        wait for half_clk_period;

        sclk <= '1';
        s2m_data(data_index) := miso;
        wait for half_clk_period;
      end loop;

      sclk <= '0';
      mosi <= '-';
      wait for half_clk_period;

    elsif cpol = '1' and cpha = '0' then

      for data_index in m2s_data'length-1 downto 0 loop
        sclk <= '1';
        mosi <= m2s_data(data_index);
        wait for half_clk_period;

        sclk <= '0';
        s2m_data(data_index) := miso;
        wait for half_clk_period;
      end loop;

      sclk <= '1';
      mosi <= '-';
      wait for half_clk_period;

    elsif cpol = '0' and cpha = '1' then

      mosi <= '-';
      wait for half_clk_period;

      for data_index in m2s_data'length-1 downto 0 loop
        sclk <= '1';
        mosi <= m2s_data(data_index);
        wait for half_clk_period;

        sclk <= '0';
        s2m_data(data_index) := miso;
        wait for half_clk_period;
      end loop;

    elsif cpol = '1' and cpha = '1' then

      mosi <= '-';
      wait for half_clk_period;

      for data_index in m2s_data'length-1 downto 0 loop
        sclk <= '0';
        mosi <= m2s_data(data_index);
        wait for half_clk_period;

        sclk <= '1';
        s2m_data(data_index) := miso;
        wait for half_clk_period;
      end loop;
    end if;

    ss_n <= '1';
    mosi <= 'Z';

    debug("Received " & to_string(s2m_data));
  end procedure spi_master_transaction;

  procedure spi_slave_transaction
  (
    constant cpol: in std_logic;
    constant cpha: in std_logic;

    variable s2m_data: in std_logic_vector;
    variable m2s_data: out std_logic_vector;

    signal ss_n: in std_logic;
    signal sclk: in std_logic;
    signal mosi: in std_logic;
    signal miso: out std_logic
  )
  is
  begin
    debug("Sending " & to_string(s2m_data));

    if cpol = '0' and cpha = '0' then
      for data_index in m2s_data'length-1 downto 0 loop
        miso <= s2m_data(data_index);
        wait until rising_edge(sclk);
        m2s_data(data_index) := mosi;
        wait until falling_edge(sclk);
      end loop;
      miso <= '-';
    elsif cpol = '1' and cpha = '0' then
      for data_index in m2s_data'length-1 downto 0 loop
        miso <= s2m_data(data_index);
        wait until falling_edge(sclk);
        m2s_data(data_index) := mosi;
        wait until rising_edge(sclk);
      end loop;
      miso <= '-';
    elsif cpol = '0' and cpha = '1' then
      miso <= '-';
      for data_index in m2s_data'length-1 downto 0 loop
        wait until rising_edge(sclk);
        miso <= s2m_data(data_index);
        wait until falling_edge(sclk);
        m2s_data(data_index) := mosi;
      end loop;
    elsif cpol = '1' and cpha = '1' then
      miso <= '-';
      for data_index in m2s_data'length-1 downto 0 loop
        wait until falling_edge(sclk);
        miso <= s2m_data(data_index);
        wait until rising_edge(sclk);
        m2s_data(data_index) := mosi;
      end loop;
    end if;

    debug("Received " & to_string(m2s_data));
  end procedure spi_slave_transaction;

  procedure nudge
  (
    signal irq: out std_logic
  )
  is
  begin
    irq <= '1';
    wait for 0 ns;
    irq <= '0';
    wait for 0 ns;
  end procedure nudge;
end package body;