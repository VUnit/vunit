-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

package axi_pkg is

  type axi_addr_m2s_t is record
    valid : std_logic;
    id : std_logic_vector(1 downto 0);
    addr : std_logic_vector(32-1 downto 0);
    len : std_logic_vector(7 downto 0);
    size : std_logic_vector(2 downto 0);
    burst : std_logic_vector(1 downto 0);
  end record;
  constant axi_addr_m2s_init : axi_addr_m2s_t := (valid => '0',
                                                  id => (others => '0'),
                                                  addr => (others => '0'),
                                                  len => (others => '0'),
                                                  size => (others => '0'),
                                                  burst => (others => '0'));

  type axi_addr_s2m_t is record
    ready : std_logic;
  end record;
  constant axi_addr_s2m_init : axi_addr_s2m_t := (ready => '0');

  type axi_read_m2s_t is record
    ready : std_logic;
  end record;
  constant axi_read_m2s_init : axi_read_m2s_t := (ready => '0');

  type axi_read_s2m_t is record
    valid : std_logic;
    id : std_logic_vector(1 downto 0);
    data : std_logic_vector(128-1 downto 0);
    resp : std_logic_vector(1 downto 0);
    last : std_logic;
  end record;
  constant axi_read_s2m_init : axi_read_s2m_t := (valid => '0',
                                                  id => (others => '0'),
                                                  data => (others => '0'),
                                                  resp => (others => '0'),
                                                  last => '0');

  type axi_write_m2s_t is record
    valid : std_logic;
    data : std_logic_vector(128-1 downto 0);
    strb : std_logic_vector(16-1 downto 0);
    last : std_logic;
  end record;
  constant axi_write_m2s_init : axi_write_m2s_t := (valid => '0',
                                                    data => (others => '0'),
                                                    strb => (others => '0'),
                                                    last => '0');

  type axi_write_s2m_t is record
    ready : std_logic;
  end record;
  constant axi_write_s2m_init : axi_write_s2m_t := (ready => '0');

  type axi_wresp_m2s_t is record
    ready : std_logic;
  end record;
  constant axi_wresp_m2s_init : axi_wresp_m2s_t := (ready => '0');

  type axi_wresp_s2m_t is record
    valid : std_logic;
    id : std_logic_vector(1 downto 0);
    resp : std_logic_vector(1 downto 0);
  end record;
  constant axi_wresp_s2m_init : axi_wresp_s2m_t := (valid => '0',
                                                    id => (others => '0'),
                                                    resp => (others => '0'));

  type axi_rd_m2s_t is record
    ar : axi_addr_m2s_t;
    r : axi_read_m2s_t;
  end record;
  constant axi_rd_m2s_init : axi_rd_m2s_t := (ar => axi_addr_m2s_init,
                                              r => axi_read_m2s_init);

  type axi_rd_s2m_t is record
    ar : axi_addr_s2m_t;
    r : axi_read_s2m_t;
  end record;
  constant axi_rd_s2m_init : axi_rd_s2m_t := (ar => axi_addr_s2m_init,
                                              r => axi_read_s2m_init);

  type axi_wr_m2s_t is record
    aw : axi_addr_m2s_t;
    w : axi_write_m2s_t;
    b : axi_wresp_m2s_t;
  end record;
  constant axi_wr_m2s_init : axi_wr_m2s_t := (aw => axi_addr_m2s_init,
                                              w => axi_write_m2s_init,
                                              b => axi_wresp_m2s_init);

  type axi_wr_s2m_t is record
    aw : axi_addr_s2m_t;
    w : axi_write_s2m_t;
    b : axi_wresp_s2m_t;
  end record;
  constant axi_wr_s2m_init : axi_wr_s2m_t := (aw => axi_addr_s2m_init,
                                              w => axi_write_s2m_init,
                                              b => axi_wresp_s2m_init);

  constant axi_response_ok : std_logic_vector(1 downto 0) := "00";
  constant axi_response_decerr : std_logic_vector(1 downto 0) := "11";
  constant axi_burst_incr : std_logic_vector(1 downto 0) := "01";

end package;
