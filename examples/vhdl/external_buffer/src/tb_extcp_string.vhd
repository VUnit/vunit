-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

-- NOTE: This file is expected to be used along with foreign languages (C)
-- through VHPIDIRECT: https://ghdl.readthedocs.io/en/latest/using/Foreign.html
-- See main.c for an example of a wrapper application.

--library vunit_lib;
--context vunit_lib.vunit_context;

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.types_pkg.all;
use vunit_lib.string_ptr_pkg.all;

entity tb_extcp_string is
  generic ( runner_cfg : string );
end entity;

architecture tb of tb_extcp_string is

  constant block_len : natural := 10;

  constant ebuf: string_ptr_t := new_string_ptr( block_len, extfnc, 0);  -- external through VHPIDIRECT functions 'read_char' and 'write_char'
  constant abuf: string_ptr_t := new_string_ptr( block_len, extacc, 1);  -- external through access (requires VHPIDIRECT function 'get_string_ptr')

begin

  main: process
    variable val: character;
  begin
    test_runner_setup(runner, runner_cfg);
    info("Init test");
    for x in 1 to block_len loop
      val := get(ebuf, x);
      set(abuf, x, val);
      info("SET " & to_string(x) & ": " & to_string(val));
    end loop;
    info("End test");
    test_runner_cleanup(runner);
    wait;
  end process;

end architecture;
