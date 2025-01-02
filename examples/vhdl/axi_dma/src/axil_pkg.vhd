-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Defines AXI4-lite data bus types

library ieee;
use ieee.std_logic_1164.all;

package axil_pkg is

  type axil_addr_m2s_t is record
    valid : std_logic;
    addr : std_logic_vector(32-1 downto 0);
  end record;
  constant axil_addr_m2s_init : axil_addr_m2s_t := (valid => '0',
                                                    addr => (others => '0'));

  type axil_addr_s2m_t is record
    ready : std_logic;
  end record;
  constant axil_addr_s2m_init : axil_addr_s2m_t := (ready => '0');

  type axil_read_m2s_t is record
    ready : std_logic;
  end record;
  constant axil_read_m2s_init : axil_read_m2s_t := (ready => '0');

  type axil_read_s2m_t is record
    valid : std_logic;
    data : std_logic_vector(32-1 downto 0);
    resp : std_logic_vector(1 downto 0);
  end record;
  constant axil_read_s2m_init : axil_read_s2m_t := (valid => '0',
                                                    data => (others => '0'),
                                                    resp => (others => '0'));

  type axil_write_m2s_t is record
    valid : std_logic;
    data : std_logic_vector(32-1 downto 0);
    strb : std_logic_vector(4-1 downto 0);
  end record;
  constant axil_write_m2s_init : axil_write_m2s_t := (valid => '0',
                                                      data => (others => '0'),
                                                      strb => (others => '0'));

  type axil_write_s2m_t is record
    ready : std_logic;
  end record;
  constant axil_write_s2m_init : axil_write_s2m_t := (ready => '0');

  type axil_wresp_m2s_t is record
    ready : std_logic;
  end record;
  constant axil_wresp_m2s_init : axil_wresp_m2s_t := (ready => '0');

  type axil_wresp_s2m_t is record
    valid : std_logic;
    resp : std_logic_vector(1 downto 0);
  end record;
  constant axil_wresp_s2m_init : axil_wresp_s2m_t := (valid => '0',
                                                      resp => (others => '0'));

  type axil_m2s_t is record
    ar : axil_addr_m2s_t;
    aw : axil_addr_m2s_t;
    r : axil_read_m2s_t;
    w : axil_write_m2s_t;
    b : axil_wresp_m2s_t;
  end record;
   constant axil_m2s_init : axil_m2s_t := (ar => axil_addr_m2s_init,
                                          aw => axil_addr_m2s_init,
                                          r => axil_read_m2s_init,
                                          w => axil_write_m2s_init,
                                          b => axil_wresp_m2s_init);

  type axil_s2m_t is record
    ar : axil_addr_s2m_t;
    aw : axil_addr_s2m_t;
    r : axil_read_s2m_t;
    w : axil_write_s2m_t;
    b : axil_wresp_s2m_t;
  end record;
  constant axil_s2m_init : axil_s2m_t := (ar => axil_addr_s2m_init,
                                          aw => axil_addr_s2m_init,
                                          r => axil_read_s2m_init,
                                          w => axil_write_s2m_init,
                                          b => axil_wresp_s2m_init);
end package;
