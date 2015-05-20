-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
use vunit_lib.log_pkg.all;

package uart_model_pkg is
  procedure uart_recv(variable byte : out integer;
                      signal tx : in std_logic;
                      baud_rate : integer);
  procedure uart_send(byte : integer;
                      signal rx : out std_logic;
                      baud_rate  : integer);
end package;

package body uart_model_pkg is
  procedure uart_recv(variable byte : out integer;
                      signal tx : in std_logic;
                      baud_rate : integer) is
    constant time_per_bit : time := (10**9 / baud_rate) * 1 ns;
    constant time_per_half_bit : time := (10**9 / (2*baud_rate)) * 1 ns;
    variable data : std_logic_vector(7 downto 0);
  begin
    wait until tx = '0';
    wait for time_per_half_bit; -- middle of start bit
    assert tx = '0';
    wait for time_per_bit; -- skip start bit
    for i in 0 to 7 loop
      data(i) := tx;
      wait for time_per_bit;
    end loop;
    assert tx = '1';
    wait for time_per_half_bit;
    byte := to_integer(unsigned(data));
  end procedure;

  procedure uart_send(byte : integer;
                      signal rx : out std_logic;
                      baud_rate  : integer) is
    constant time_per_bit : time := (10**9 / baud_rate) * 1 ns;

    procedure send_bit(value : std_logic) is
    begin
      rx <= value;
      wait for time_per_bit;
    end procedure;

  begin
    debug("Sending " & to_string(byte));
    send_bit('0');
    for i in 0 to 7 loop
      if (byte/2**i) mod 2 = 1 then
        send_bit('1');
     else
        send_bit('0');
     end if;
    end loop;
    send_bit('1');
  end procedure;
end package body;
