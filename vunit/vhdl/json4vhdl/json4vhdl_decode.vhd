-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
library vunit_lib;
context vunit_lib.vunit_context;

use vunit_lib.json.T_JSON;
use vunit_lib.json.jsonGetString;

package json4vhdl_decode is
  impure function decode_array(Content : T_JSON; Path : string) return integer_vector;
end;

package body json4vhdl_decode is
  -- function to get a integer_vector from the compressed content extracted from a JSON input
  impure function decode_array(Content : T_JSON; Path : string) return integer_vector is
  variable len: positive:=positive'value( jsonGetString(Content, Path & "/0") );
  variable return_value : integer_vector(len-1 downto 0);
  begin
    for i in 1 to len loop
      return_value(i-1) := integer'value(jsonGetString(Content, Path & "/" & to_string(i)));
    end loop;

    return return_value;
  end;
end package body;
