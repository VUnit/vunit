-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

package pkg_c is

  function get_param(f: integer) return integer;
    attribute foreign of get_param : function is "VHPIDIRECT get_param";

  procedure write_byte ( id, i, v: integer ) ;
    attribute foreign of write_byte : procedure is "VHPIDIRECT write_byte";

  impure function read_byte ( id, i: integer ) return integer;
    attribute foreign of read_byte : function is "VHPIDIRECT read_byte";

  type memory_t is record
    -- Private
    p_id: integer;
  end record;

  impure function new_memory(id: integer := -1) return memory_t;
  procedure write_word ( memory: memory_t; i: natural; w: std_logic_vector );
  impure function read_word ( memory: memory_t; i, bytes_per_word: integer ) return std_logic_vector;

  procedure write_byte ( memory: memory_t; i: integer; v: std_logic_vector(7 downto 0) );
  impure function read_byte ( memory: memory_t; i: integer ) return std_logic_vector;

end pkg_c;

package body pkg_c is

  -- VHPI

  function get_param(f: integer) return integer is begin
    assert false report "VHPI" severity failure;
  end function;

  procedure write_byte ( id, i, v: integer ) is begin
    assert false report "VHPI" severity failure;
  end procedure;

  impure function read_byte ( id, i: integer ) return integer is begin
    assert false report "VHPI" severity failure;
  end function;

  -- VHDL

  procedure write_byte ( memory: memory_t; i: integer; v: std_logic_vector(7 downto 0) ) is
  begin
    write_byte(memory.p_id, i, to_integer(unsigned(v)));
  end procedure;

  impure function read_byte ( memory: memory_t; i: integer ) return std_logic_vector is begin
    return std_logic_vector(to_unsigned(read_byte(memory.p_id, i), 8));
  end function;

  impure function new_memory(id: integer := -1) return memory_t is begin
    return (p_id => id);
  end;

  procedure write_word ( memory: memory_t; i: natural; w: std_logic_vector ) is begin
    for idx in 0 to w'length/8-1 loop
      write_byte(memory, i + idx, w(8*idx+7 downto 8*idx));
    end loop;
  end procedure;

  impure function read_word ( memory: memory_t; i, bytes_per_word: integer ) return std_logic_vector is
    variable tmp: std_logic_vector(31 downto 0);
  begin
    for idx in 0 to bytes_per_word-1 loop
      tmp(8*idx+7 downto 8*idx) := read_byte(memory, i + idx);
    end loop;
    return tmp;
  end function;

end pkg_c;
