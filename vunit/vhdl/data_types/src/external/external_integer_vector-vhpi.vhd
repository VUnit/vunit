-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.types_pkg.all;

package external_integer_vector_pkg is
  procedure write_integer (
    id : integer;
    i  : integer;
    v  : integer
  );

  impure function read_integer (
    id : integer;
    i  : integer
  ) return integer;

  impure function get_ptr (
    id : integer
  ) return extintvec_access_t;

  attribute foreign of write_integer : procedure is "VHPIDIRECT write_integer";
  attribute foreign of read_integer  : function  is "VHPIDIRECT read_integer";
  attribute foreign of get_ptr       : function  is "VHPIDIRECT get_intvec_ptr";
end package;
