-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use work.dict_pkg.all;
use work.codec_2008p_pkg.all;
use work.data_types_private_pkg.all;

package dict_2008p_pkg is
  procedure set (
    dict       : dict_t;
    key        : string;
    value      : boolean_vector
  );
  alias set_boolean_vector is set[dict_t, string, boolean_vector];

  impure function get (
    dict : dict_t;
    key  : string
  ) return boolean_vector;
  alias get_boolean_vector is get[dict_t, string return boolean_vector];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : time_vector
  );
  alias set_time_vector is set[dict_t, string, time_vector];

  impure function get (
    dict : dict_t;
    key  : string
  ) return time_vector;
  alias get_time_vector is get[dict_t, string return time_vector];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : real_vector
  );
  alias set_real_vector is set[dict_t, string, real_vector];

  impure function get (
    dict : dict_t;
    key  : string
  ) return real_vector;
  alias get_real_vector is get[dict_t, string return real_vector];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : integer_vector
  );
  alias set_integer_vector is set[dict_t, string, integer_vector];

  impure function get (
    dict : dict_t;
    key  : string
  ) return integer_vector;
  alias get_integer_vector is get[dict_t, string return integer_vector];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : ufixed
  );
  alias set_ufixed is set[dict_t, string, ufixed];

  impure function get (
    dict : dict_t;
    key  : string
  ) return ufixed;
  alias get_ufixed is get[dict_t, string return ufixed];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : sfixed
  );
  alias set_sfixed is set[dict_t, string, sfixed];

  impure function get (
    dict : dict_t;
    key  : string
  ) return sfixed;
  alias get_sfixed is get[dict_t, string return sfixed];

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : float
  );
  alias set_float is set[dict_t, string, float];

  impure function get (
    dict : dict_t;
    key  : string
  ) return float;
  alias get_float is get[dict_t, string return float];

end package;

package body dict_2008p_pkg is
  procedure set (
    dict       : dict_t;
    key        : string;
    value      : boolean_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_boolean_vector);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return boolean_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_boolean_vector));
  end;

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : time_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_time_vector);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return time_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_time_vector));
  end;

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : real_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_real_vector);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return real_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_real_vector));
  end;

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : integer_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_integer_vector);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return integer_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_integer_vector));
  end;

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : ufixed
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_ufixed);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return ufixed is
  begin
    return decode(p_get_with_type(dict, key, ieee_ufixed));
  end;

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : sfixed
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_sfixed);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return sfixed is
  begin
    return decode(p_get_with_type(dict, key, ieee_sfixed));
  end;

  procedure set (
    dict       : dict_t;
    key        : string;
    value      : float
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_float);
  end;

  impure function get (
    dict : dict_t;
    key  : string
  ) return float is
  begin
    return decode(p_get_with_type(dict, key, ieee_float));
  end;

end package body;
