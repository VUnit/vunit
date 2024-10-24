-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.memory_pkg.all;
use work.apb_pkg.all;
use work.logger_pkg.all;

entity apb_slave is
  generic (
    bus_handle        : apb_slave_t;
    drive_invalid     : boolean := true;
    drive_invalid_val : std_logic := 'X'
  );
  port (
    clk                 : in  std_logic;
    reset               : in  std_logic;
    psel_i              : in  std_logic;
    penable_i           : in  std_logic;
    paddr_i             : in  std_logic_vector;
    pwrite_i            : in  std_logic;
    pwdata_i            : in  std_logic_vector;
    prdata_o            : out std_logic_vector;
    pready_o            : out std_logic
  );
end entity;

architecture a of apb_slave is
    
begin

  PROC_MAIN: process
    procedure drive_outputs_invalid is
    begin
      if drive_invalid then
        prdata_o <= (prdata_o'range => drive_invalid_val);
        pready_o <= drive_invalid_val;
      end if;
    end procedure;

    variable addr : integer;
  begin
    drive_outputs_invalid;
    wait until rising_edge(clk);

    loop
      -- IDLE/SETUP state
      drive_outputs_invalid;

      wait until psel_i = '1' and rising_edge(clk);
      -- ACCESS state

      pready_o <= '1';

      addr := to_integer(unsigned(paddr_i));

      if pwrite_i = '1' then
        write_word(bus_handle.p_memory, addr, pwdata_i);
      else
        prdata_o <= read_word(bus_handle.p_memory, addr, prdata_o'length/8);
      end if;

      wait until rising_edge(clk);

      if penable_i = '0' then
        failure(bus_handle.p_logger, "penable_i must be active in the ACCESS phase.");
      end if; 
    end loop;
  end process;

end architecture;