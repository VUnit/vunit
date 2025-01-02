-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
use std.textio.all;

entity verification_component_y is
  generic(
    name : string
  );
  port(
    q : in bit
  );
end;

architecture a of verification_component_y is
begin
  check_coverage : process
    impure function exists(path : string) return boolean is
      file f : text;
      variable status : file_open_status;
    begin
      file_open(status, f, path, read_mode);
      if status /= open_ok then
        return false;
      end if;
      file_close(f);
      return true;
    end;
  begin
    wait until q = '0';
    wait until q = '1';
    if not exists("./log.txt") then
      print("Irq 0x7 activated (" & name & ").", "./log.txt", append_mode);
    end if;
    wait;
  end process;
end;
