-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- pragma translate_off
library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
-- pragma translate_on

entity uart_tx is
  generic (
    cycles_per_bit : natural := 434);
  port (
   clk : in std_logic;

   -- Serial output bit
   tx : out std_logic := '1';

   -- AXI stream for input bytes
   tready : out std_logic := '0';
   tvalid : in std_Logic;
   tdata : in std_logic_vector(7 downto 0));
begin
  -- pragma translate_off
  check_stable(clk, check_enabled, tvalid, tready, tdata, "tdata must be stable until tready is active");
  check_stable(clk, check_enabled, tvalid, tready, tvalid, "tvalid must be active until tready is active");
  check_not_unknown(clk, check_enabled, tvalid, "tvalid must never be unknown");
  check_not_unknown(clk, check_enabled, tready, "tready must never be unknown");
  check_not_unknown(clk, check_enabled, tx, "tx must never be unknown");
  traffic_logger: process (clk) is
  begin
    if tvalid = '1' and tready = '1' and rising_edge(clk) then
      debug("Sending " & to_string(to_integer(unsigned(tdata))));
    end if;
  end process traffic_logger;
  -- pragma translate_on
end entity;

architecture a of uart_tx is
  signal tready_int : std_logic := '0';
begin
  main : process (clk)
    type state_t is (idle, sending);
    variable state : state_t := idle;
    variable cycles : natural range 0 to cycles_per_bit-1 := 0;
    variable data : std_logic_vector(9 downto 0);
    variable index : natural range 0 to data'length-1 := 0;
  begin
    if rising_edge(clk) then
      case state is
        when idle =>
          tx <= '1';
          if tvalid = '1' and tready_int = '1' then
            state := sending;
            cycles := 0;
            index := 0;
            data := '1' & tdata & '0';
          end if;
        when sending =>
          tx <= data(0);

          if cycles = cycles_per_bit - 1 then
            if index = data'length-1 then
              state := idle;
            else
              index := index + 1;
            end if;
            data := '0' & data(data'left downto 1);
            cycles := 0;
          else
            cycles := cycles + 1;
          end if;
      end case;

      if state = idle then
        tready_int <= '1';
      else
        tready_int <= '0';
      end if;
    end if;
  end process;

  tready <= tready_int;
end architecture;
