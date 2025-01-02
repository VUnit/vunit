-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity axi_burst_gen is
  generic (
    max_burst_length : natural range 1 to 256;
    bytes_per_beat : natural
    );
  port (
    clk : in std_logic;

    -- Start pulse
    start : in std_logic;
    start_addr : in std_logic_vector(31 downto 0);
    num_bytes : in std_logic_vector(31 downto 0);

    -- Output burst stream
    burst_valid : out std_logic := '0';
    burst_ready : in std_logic;
    burst_addr : out std_logic_vector(31 downto 0) := (others => '0');
    burst_length : out natural range 1 to max_burst_length := 1;
    burst_last : out std_logic := '0');
end entity;


architecture a of axi_burst_gen is
  constant c4kbyte : natural := 4096;

  type state_t is (idle,
                   compute_burst_length0,
                   compute_burst_length1,
                   compute_is_last,
                   await_accept);
  signal state : state_t := idle;
  signal addr, remaining_bytes : unsigned(start_addr'range);
begin
  main : process
  begin
    wait until rising_edge(clk);

    case state is
      when idle =>
        if start = '1' then
          addr <= unsigned(start_addr);
          remaining_bytes <= unsigned(num_bytes);
          state <= compute_burst_length0;
        end if;

      when compute_burst_length0 =>
        if max_burst_length <= to_integer(remaining_bytes) / bytes_per_beat then
          burst_length <= max_burst_length;
        else
          burst_length <= to_integer(remaining_bytes) / bytes_per_beat;
        end if;

        state <= compute_burst_length1;

      when compute_burst_length1 =>
        if (to_integer(addr)/c4kbyte) /= (to_integer(addr) + burst_length * bytes_per_beat - 1)/c4kbyte then
          burst_length <= (-(to_integer(addr)/bytes_per_beat)) mod (c4kbyte/bytes_per_beat);
        end if;

        state <= compute_is_last;

      when compute_is_last =>
        burst_valid <= '1';

        if remaining_bytes = burst_length * bytes_per_beat then
          burst_last <= '1';
        else
          burst_last <= '0';
        end if;

        state <= await_accept;

      when await_accept =>
        if burst_ready = '1' then
          burst_valid <= '0';
          addr <= addr + burst_length * bytes_per_beat;
          remaining_bytes <= remaining_bytes - burst_length * bytes_per_beat;
          if burst_last = '1' then
            state <= idle;
          else
            state <= compute_burst_length0;
          end if;
        end if;

    end case;

  end process;

  burst_addr <= std_logic_vector(addr);

end;
