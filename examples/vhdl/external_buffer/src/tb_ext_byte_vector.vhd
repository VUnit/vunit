-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

-- NOTE: This file is expected to be used along with foreign languages (C)
-- through VHPIDIRECT: https://ghdl.readthedocs.io/en/latest/using/Foreign.html
-- See main.c for an example of a wrapper application.

--library vunit_lib;
--context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.types_pkg.all;
use vunit_lib.byte_vector_ptr_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.clk_pkg.all;

entity tb_external_byte_vector is
  generic ( runner_cfg : string );
end entity;

architecture tb of tb_external_byte_vector is

  constant params: integer_vector_ptr_t := new_integer_vector_ptr(6, extacc, 0);

  constant clk_step   : natural := get(params, 2);
  constant block_len  : integer := get(params, 4);

  constant ebuf: byte_vector_ptr_t := new_byte_vector_ptr( 3*block_len, extfnc, 1);  -- external through VHPIDIRECT functions 'read_char' and 'write_char'
  constant abuf: byte_vector_ptr_t := new_byte_vector_ptr( 3*block_len, extacc, 1);  -- external through access (requires VHPIDIRECT function 'get_string_ptr')

  signal clk, rst, rstn : std_logic := '0';
  signal done, tg, start : boolean := false;

begin

  rstn <= not rst;

  clk_gen: entity vunit_lib.clk_handler generic map ( params ) port map ( rst, clk, tg );

  run: process(tg) begin if rising_edge(tg) then
    info("UPDATE READY");
    set(params, 3, 1);
  end if; end process;

  main: process begin
    test_runner_setup(runner, runner_cfg);
    rst <= '1';
    info("Init test: " & to_string(block_len));
    wait for 100 ns;
    rst <= '0';
    info("wait_load");
    wait_load(params);
    info("start");
    start <= true;
    info("wait_sync");
    wait_sync(params, done, tg);
    info("Test done");
    test_runner_cleanup(runner);
    wait;
  end process;

  stimuli: process
    variable val, ind: integer;
  begin
    wait until start;
    wait_for(clk, 1);
    for x in 0 to block_len-1 loop
      val := get(ebuf, x) + 1;
      ind := block_len+x;
      set(ebuf, ind, val);
      info("SET " & to_string(ind) & ": " & to_string(val));
      wait_for(clk, 1);
    end loop;
    for x in block_len to 2*block_len-1 loop
      val := get(abuf, x) + 2;
      ind := block_len+x;
      set(abuf, ind, val);
      info("SET " & to_string(ind) & ": " & to_string(val));
      wait_for(clk, 1);
    end loop;
    info("done");
    done <= true;
    wait;
  end process;

end architecture;
