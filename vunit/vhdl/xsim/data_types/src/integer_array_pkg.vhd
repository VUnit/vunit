-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.codec_builder_pkg.all;
use work.codec_pkg.all;
use work.integer_vector_ptr_pkg.all;

package integer_array_pkg is
  type integer_array_t is record
    -- All fields are considered private, use functions to access these
    length : natural;
    width : natural;
    height : natural;
    depth : natural;
    bit_width : natural;
    is_signed : boolean;
    lower_limit : integer;
    upper_limit : integer;
    data : integer_vector_ptr_t;
  end record;

  -- Ensure null_integer_array is the default VHDL value of the record
  constant null_integer_array : integer_array_t := (
    length => 0,
    width => 0,
    height => 0,
    depth => 0,
    bit_width => 0,
    is_signed => false,
    lower_limit => integer'low,
    upper_limit => integer'low,
    data => null_ptr
    );

  type integer_array_vec_t is array (natural range <>) of integer_array_t;

  impure function new_1d (
    length    : integer := 0;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t;

  impure function new_2d (
    width     : integer := 0;
    height    : integer := 0;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t;

  impure function new_3d (
    width     : integer := 0;
    height    : integer := 0;
    depth     : integer := 0;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t;

  impure function copy (
    arr : integer_array_t
  ) return integer_array_t;

  impure function load_csv (
    file_name : string;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t;

  impure function load_raw (
    file_name : string;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t;

  procedure deallocate (
    variable arr : inout integer_array_t
  );

  impure function is_null (
    arr : integer_array_t
  ) return boolean;

  impure function length (
    arr : integer_array_t
  ) return integer;

  impure function width (
    arr : integer_array_t
  ) return integer;

  impure function height (
    arr : integer_array_t
  ) return integer;

  impure function depth (
    arr : integer_array_t
  ) return integer;

  impure function bit_width (
    arr : integer_array_t
  ) return integer;

  impure function is_signed (
    arr : integer_array_t
  ) return boolean;

  impure function bytes_per_word (
    arr : integer_array_t
  ) return integer;

  impure function lower_limit (
    arr : integer_array_t
  ) return integer;

  impure function upper_limit (
    arr : integer_array_t
  ) return integer;

  impure function get (
    arr : integer_array_t;
    idx : integer
  ) return integer;

  impure function get (
    arr : integer_array_t;
    x,y : integer
  ) return integer;

  impure function get (
    arr   : integer_array_t;
    x,y,z : integer
  ) return integer;

  procedure set (
    arr   : integer_array_t;
    idx   : integer;
    value : integer
  );

  procedure set (
    arr   : integer_array_t;
    x,y   : integer;
    value : integer
  );

  procedure set (
    arr   : integer_array_t;
    x,y,z : integer;
    value : integer
  );

  procedure append (
    variable arr : inout integer_array_t;
    value        : integer
  );

  procedure reshape (
    variable arr : inout integer_array_t;
    length       : integer
  );

  procedure reshape (
    variable arr  : inout integer_array_t;
    width, height : integer
  );

  procedure reshape (
    variable arr         : inout integer_array_t;
    width, height, depth : integer
  );

  procedure save_csv (
    arr       : integer_array_t;
    file_name : string
  );

  procedure save_raw (
    arr       : integer_array_t;
    file_name : string
  );

  function encode (
    data : integer_array_t
  ) return string;

  function decode (
    code : string
  ) return integer_array_t;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out integer_array_t
  );
end package;
