-- Test suite for com codec package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package add_pkg is
  function add (
    constant l, r : integer)
    return integer;
end package add_pkg;

package body add_pkg is
  function add (
    constant l, r : integer)
    return integer is
  begin
    return l + r;
  end function add;
end package body add_pkg;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use std.textio.all;
use work.add_pkg.all;

package custom_types_pkg is
  type enum1_t is (red, green, blue);

  type record1_t is record
    a       : natural;
    b, c, d : integer;
  end record record1_t;
  type record2_msg_type_t is (command);
  type record2_t is record
    msg_type : record2_msg_type_t;
    a        : natural;
    b, c, d  : integer;
  end record record2_t;
  type record3_t is record
    char : character;
  end record record3_t;

  type array1_t is array (-2 to 2) of natural ;
  type array2_t is array (2 downto -2) of natural ;
  type array3_t is array (-2 to 2, -1 to 1) of natural ;
  type array4_t is array (positive range <>) of natural ;
  type array5_t is array (integer range <>, integer range <>) of natural ;
  type fruit_t is (apple, banana, melon, kiwi, orange, papaya);
  type array6_t is array (fruit_t range <>) of natural ;
  type array7_t is array (integer range <>, fruit_t range <>) of natural ;
  type array8_t is array (add(2, -4) to 2, -1 to -1 + 2) of natural ;
  type array9_t is array (array1_t'range) of natural ;
  type array10_t is array (array1_t'range, -1 to 1) of natural ;
  

end package custom_types_pkg;



