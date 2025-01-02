-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- The purpose of this package is to provide a byte vector access type (pointer)
-- that can itself be used in arrays and returned from functions unlike a
-- real access type. This is achieved by letting the actual value be a handle
-- into a singleton datastructure of string access types.
--

use work.types_pkg.all;
use work.string_ptr_pkg.all;

package byte_vector_ptr_pkg is

  alias val_t is byte_t;

  alias byte_vector_ptr_t is string_ptr_t;
  alias null_byte_vector_ptr is null_string_ptr;

  alias new_byte_vector_ptr is new_string_ptr[string, storage_mode_t, integer return ptr_t];

  alias is_external is is_external[ptr_t return boolean];
  alias deallocate is deallocate[ptr_t];
  alias length is length[ptr_t return integer];

  impure function new_byte_vector_ptr (
    length : natural := 0;
    mode   : storage_mode_t := internal;
    eid    : index_t := -1;
    value  : val_t   := 0
  ) return ptr_t;

  procedure set (
    ptr   : ptr_t;
    index : natural;
    value : val_t
  );

  impure function get (
    ptr   : ptr_t;
    index : natural
  ) return val_t;

  procedure reallocate (
    ptr    : ptr_t;
    length : natural;
    value  : val_t := 0
  );

  procedure resize (
    ptr    : ptr_t;
    length : natural;
    drop   : natural := 0;
    value  : val_t := 0
  );
end package;

package body byte_vector_ptr_pkg is
  impure function new_byte_vector_ptr (
    length : natural := 0;
    mode   : storage_mode_t := internal;
    eid    : index_t := -1;
    value  : val_t   := 0
  ) return ptr_t is begin
    return work.string_ptr_pkg.new_string_ptr(length, mode, eid, character'val(value));
  end;

  procedure set (
    ptr   : ptr_t;
    index : natural;
    value : val_t
  ) is begin
    work.string_ptr_pkg.set(ptr, index+1, character'val(value));
  end;

  impure function get (
    ptr   : ptr_t;
    index : natural
  ) return val_t is begin
    return character'pos(work.string_ptr_pkg.get(ptr, index+1));
  end;

  procedure reallocate (
    ptr    : ptr_t;
    length : natural;
    value  : val_t := 0
  ) is begin
    work.string_ptr_pkg.reallocate(ptr, length, character'val(value));
  end;

  procedure resize (
    ptr    : ptr_t;
    length : natural;
    drop   : natural := 0;
    value  : val_t   := 0
  ) is begin
    work.string_ptr_pkg.resize(ptr, length, drop, character'val(value));
  end;
end package body;
