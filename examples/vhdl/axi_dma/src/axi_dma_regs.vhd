-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_pkg.all;
use work.axi_pkg.axi_response_ok;
use work.axi_pkg.axi_response_decerr;
use work.axi_dma_regs_pkg.all;

entity axi_dma_regs is
  port (
    clk : in std_logic;

    axils_m2s : in axil_m2s_t;
    axils_s2m : out axil_s2m_t := axil_s2m_init;

    start_transfer : out std_logic := '0';
    transfer_done : in std_logic;

    src_address : out std_logic_vector(31 downto 0);
    dst_address : out std_logic_vector(31 downto 0);
    num_bytes : out std_logic_vector(31 downto 0)
);

end entity;

architecture a of axi_dma_regs is
  type state_t is (idle,
                   writing,
                   write_response,
                   reading);
  signal state : state_t := idle;

  signal addr : std_logic_vector(axils_m2s.ar.addr'range);

  -- Compare addresses of 32-bit words discarding byte address
  function cmp_word_address(byte_addr : std_logic_vector;
                            word_addr : natural) return boolean is
  begin
    return to_integer(unsigned(byte_addr(byte_addr'left downto 2))) = word_addr/4;
  end;

begin

  main : process
  begin
    wait until rising_edge(clk);

    axils_s2m.ar.ready <= '0';
    axils_s2m.aw.ready <= '0';
    axils_s2m.w.ready <= '0';
    axils_s2m.r.valid <= '0';
    axils_s2m.r.data <= (others => '0');

    start_transfer <= '0';

    case state is
      when idle =>

        if axils_m2s.ar.valid = '1' then
          axils_s2m.ar.ready <= '1';
          addr <= axils_m2s.ar.addr;
          state <= reading;

        elsif axils_m2s.aw.valid = '1' then
          axils_s2m.aw.ready <= '1';
          addr <= axils_m2s.aw.addr;
          state <= writing;
        end if;

      when writing =>
        if axils_m2s.w.valid = '1' then
          axils_s2m.w.ready <= '1';

          axils_s2m.b.valid <= '1';
          axils_s2m.b.resp <= axi_response_ok;

          state <= write_response;

          -- Ignore byte write enable
          if cmp_word_address(addr, command_reg_addr) then
            start_transfer <= axils_m2s.w.data(start_transfer_command_bit);
          elsif cmp_word_address(addr, src_address_reg_addr) then
            src_address <= axils_m2s.w.data;
          elsif cmp_word_address(addr, dst_address_reg_addr) then
            dst_address <= axils_m2s.w.data;
          elsif cmp_word_address(addr, num_bytes_reg_addr) then
            num_bytes <= axils_m2s.w.data;
          else
            axils_s2m.b.resp <= axi_response_decerr;
          end if;
        end if;

      when write_response =>
        if axils_m2s.b.ready = '1' then
          axils_s2m.b.valid <= '0';
          state <= idle;
        end if;

      when reading =>
        if axils_s2m.r.valid = '0' then
          axils_s2m.r.valid <= '1';
          axils_s2m.r.resp <= axi_response_ok;

          if cmp_word_address(addr, status_reg_addr) then
            axils_s2m.r.data(transfer_done_status_bit) <= transfer_done;
          else
            axils_s2m.r.resp <= axi_response_decerr;
          end if;

        elsif axils_m2s.r.ready = '1' then
          state <= idle;
        end if;
    end case;

  end process;
end;
