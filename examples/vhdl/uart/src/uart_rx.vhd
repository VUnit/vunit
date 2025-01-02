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

entity uart_rx is
  generic (
    cycles_per_bit : natural := 434);
  port (
   clk : in std_logic;

   -- Serial input bit
   rx : in std_logic;

   overflow : out std_logic := '0';

   -- AXI stream for output bytes
   tready : in std_logic;
   tvalid : out std_Logic := '0';
   tdata : out std_logic_vector(7 downto 0));
begin
  -- pragma translate_off
  check_stable(clk, check_enabled, tvalid, tready, tdata, "tdata must be stable until tready is active");
  check_stable(clk, check_enabled, tvalid, tready, tvalid, "tvalid must be active until tready is active");
  check_not_unknown(clk, check_enabled, tvalid, "tvalid must never be unknown");
  check_not_unknown(clk, check_enabled, tready, "tready must never be unknown");
  check_not_unknown(clk, check_enabled, rx, "rx must never be unknown");
  traffic_logger: process (clk) is
  begin
    if tvalid = '1' and tready = '1' and rising_edge(clk) then
      debug("Received " & to_string(to_integer(unsigned(tdata))));
    end if;
  end process traffic_logger;
  -- pragma translate_on
end entity;

architecture a of uart_rx is
  signal tvalid_int : std_logic := '0';
begin
  main : process (clk)
    type state_t is (idle, receiving, done);
    variable state : state_t := idle;
    variable cycles : natural range 0 to cycles_per_bit-1 := 0;
    variable data : std_logic_vector(7 downto 0);
    variable index : natural range 0 to data'length-1 := 0;
  begin
    if rising_edge(clk) then
      overflow <= '0';

      case state is
        when idle =>
          if rx = '0' then
            if cycles = cycles_per_bit/2 - 1 then
              state := receiving;
              cycles := 0;
              index := 0;
            else
              cycles := cycles + 1;
            end if;
          else
              cycles := 0;
          end if;

        when receiving =>
          if cycles = cycles_per_bit - 1 then
            data := rx & data(data'length-1 downto 1);
            cycles := 0;

            if index = data'length - 1 then
              state := done;
            else
              index := index + 1;
            end if;
          else
            cycles := cycles + 1;
          end if;

        when done =>
          -- New output overwrites old output
          overflow <= tvalid_int and not tready;
          tvalid_int <= '1';
          tdata <= data;
          state := idle;
      end case;

      -- output was read
      if tvalid_int = '1' and tready = '1' then
        tvalid_int <= '0';
      end if;

    end if;
  end process;

  tvalid <= tvalid_int;
end architecture;
