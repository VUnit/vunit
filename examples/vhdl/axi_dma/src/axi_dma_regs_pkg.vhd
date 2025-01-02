-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

package axi_dma_regs_pkg is
  constant command_reg_addr : natural := 0;
  constant status_reg_addr : natural := 4;
  constant src_address_reg_addr : natural := 8;
  constant dst_address_reg_addr : natural := 12;
  constant num_bytes_reg_addr : natural := 16;

  constant start_transfer_command_bit : natural := 0;
  constant start_transfer_command : std_logic_vector(31 downto 0) := (
    start_transfer_command_bit => '1',
    others => '0');

  constant transfer_done_status_bit : natural := 0;
  constant transfer_done_status : std_logic_vector(31 downto 0) := (
    transfer_done_status_bit => '1',
    others => '0');
end package;
