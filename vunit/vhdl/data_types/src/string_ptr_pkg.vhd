-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- The purpose of this package is to provide an string access type (pointer)
-- that can itself be used in arrays and returned from functions unlike a
-- real access type. This is achieved by letting the actual value be a handle
-- into a singleton datastructure of string access types.
--

use work.types_pkg.all;
use work.codec_builder_pkg.decode;
use work.codec_builder_pkg.integer_code_length;
use work.codec_pkg.encode;
use work.external_string_pkg.all;

package string_ptr_pkg is

  type string_ptr_t is record
    ref : index_t;
  end record;
  constant null_string_ptr : string_ptr_t := (ref => -1);

  alias  ptr_t  is string_ptr_t;
  alias  val_t  is character;
  alias  vec_t  is string;
  alias  vav_t  is string_access_vector_t;
  alias evav_t  is extstring_access_vector_t;
  alias  vava_t is string_access_vector_access_t;
  alias evava_t is extstring_access_vector_access_t;

  function to_integer (
    value : ptr_t
  ) return integer;

  impure function to_string_ptr (
    value : integer
  ) return ptr_t;

  impure function new_string_ptr (
    length : natural := 0;
    mode   : storage_mode_t := internal;
    eid    : index_t := -1;
    value  : val_t   := val_t'low
  ) return ptr_t;

  impure function new_string_ptr (
    value : string;
    mode  : storage_mode_t := internal;
    eid   : index_t := -1
  ) return ptr_t;

  impure function is_external (
    ptr : ptr_t
  ) return boolean;

  procedure deallocate (
    ptr : ptr_t
  );

  impure function length (
    ptr : ptr_t
  ) return integer;

  procedure set (
    ptr   : ptr_t;
    index : positive;
    value : val_t
  );

  impure function get (
    ptr   : ptr_t;
    index : positive
  ) return val_t;

  procedure reallocate (
    ptr    : ptr_t;
    length : natural;
    value  : val_t := val_t'low
  );

  procedure reallocate (
    ptr   : ptr_t;
    value : vec_t
  );

  procedure resize (
    ptr    : ptr_t;
    length : natural;
    drop   : natural := 0;
    value  : val_t   := val_t'low
  );

  impure function to_string (
    ptr : ptr_t
  ) return string;

  function encode (
    data : ptr_t
  ) return string;

  function decode (
    code : string
  ) return ptr_t;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out ptr_t
  );

  alias encode_ptr_t is encode[ptr_t return string];
  alias decode_ptr_t is decode[string return ptr_t];

  constant string_ptr_t_code_length : positive := integer_code_length;

end package;
