-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;

entity verification_component_x_with_logger is
  generic(
    verbose_file_handler : log_handler_t;
    do_log : boolean := true;
    id : id_t := null_id
  );
end;

architecture a of verification_component_x_with_logger is
begin
process
    variable acme_corp_id, vc_x_id, my_id : id_t;
    variable logger : logger_t;
    variable data, addr : std_logic_vector(31 downto 0);
  begin
    -- start_snippet null_id
    if id = null_id then
      acme_corp_id := get_id("Acme Corporation");
      vc_x_id := get_id("vc_x", parent => acme_corp_id);
      my_id := get_id(to_string(num_children(vc_x_id) + 1), parent => vc_x_id);
      logger := get_logger(my_id);
    else
      logger := get_logger(id);
    end if;

    -- start_folding ...
    wait for 10 ns;
    if do_log then
      show(logger, verbose_file_handler, debug);
      show(logger, display_handler, debug);
    end if;

    data := x"deadbeef";
    addr := x"12345678";
    -- end_folding ...

    debug(logger, "Writing 0x" & to_hstring(data) & " to address 0x" & to_hstring(addr) & ".");
    -- end_snippet null_id
    wait;
  end process;

end;
