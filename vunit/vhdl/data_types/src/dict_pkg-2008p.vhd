-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use work.dict_pkg.all;
use work.codec_2008p_pkg.all;
use work.data_types_private_pkg.all;

package dict_2008p_pkg is
  procedure set_boolean_vector (
    dict       : dict_t;
    key        : string;
    value      : boolean_vector
  );

  impure function get_boolean_vector (
    dict : dict_t;
    key  : string
  ) return boolean_vector;

  procedure set_time_vector (
    dict       : dict_t;
    key        : string;
    value      : time_vector
  );

  impure function get_time_vector (
    dict : dict_t;
    key  : string
  ) return time_vector;

  procedure set_real_vector (
    dict       : dict_t;
    key        : string;
    value      : real_vector
  );

  impure function get_real_vector (
    dict : dict_t;
    key  : string
  ) return real_vector;

  procedure set_integer_vector (
    dict       : dict_t;
    key        : string;
    value      : integer_vector
  );

  impure function get_integer_vector (
    dict : dict_t;
    key  : string
  ) return integer_vector;

  procedure set_ufixed (
    dict       : dict_t;
    key        : string;
    value      : ufixed
  );

  impure function get_ufixed (
    dict : dict_t;
    key  : string
  ) return ufixed;

  procedure set_sfixed (
    dict       : dict_t;
    key        : string;
    value      : sfixed
  );

  impure function get_sfixed (
    dict : dict_t;
    key  : string
  ) return sfixed;

  procedure set_float (
    dict       : dict_t;
    key        : string;
    value      : float
  );

  impure function get_float (
    dict : dict_t;
    key  : string
  ) return float;

end package;

package body dict_2008p_pkg is
  procedure set_boolean_vector (
    dict       : dict_t;
    key        : string;
    value      : boolean_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_boolean_vector);
  end;

  impure function get_boolean_vector (
    dict : dict_t;
    key  : string
  ) return boolean_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_boolean_vector));
  end;

  procedure set_time_vector (
    dict       : dict_t;
    key        : string;
    value      : time_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_time_vector);
  end;

  impure function get_time_vector (
    dict : dict_t;
    key  : string
  ) return time_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_time_vector));
  end;

  procedure set_real_vector (
    dict       : dict_t;
    key        : string;
    value      : real_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_real_vector);
  end;

  impure function get_real_vector (
    dict : dict_t;
    key  : string
  ) return real_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_real_vector));
  end;

  procedure set_integer_vector (
    dict       : dict_t;
    key        : string;
    value      : integer_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_integer_vector);
  end;

  impure function get_integer_vector (
    dict : dict_t;
    key  : string
  ) return integer_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_integer_vector));
  end;

  procedure set_ufixed (
    dict       : dict_t;
    key        : string;
    value      : ufixed
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_ufixed);
  end;

  impure function get_ufixed (
    dict : dict_t;
    key  : string
  ) return ufixed is
  begin
    return decode(p_get_with_type(dict, key, ieee_ufixed));
  end;

  procedure set_sfixed (
    dict       : dict_t;
    key        : string;
    value      : sfixed
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_sfixed);
  end;

  impure function get_sfixed (
    dict : dict_t;
    key  : string
  ) return sfixed is
  begin
    return decode(p_get_with_type(dict, key, ieee_sfixed));
  end;

  procedure set_float (
    dict       : dict_t;
    key        : string;
    value      : float
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_float);
  end;

  impure function get_float (
    dict : dict_t;
    key  : string
  ) return float is
  begin
    return decode(p_get_with_type(dict, key, ieee_float));
  end;

end package body;
