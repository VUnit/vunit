-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package types_pkg is
  subtype index_t is integer range -1 to integer'high;
  subtype byte_t is integer range 0 to 255;
  type storage_mode_t is (internal, extfnc, extacc);

  type string_access_t is access string;
  type string_access_vector_t is array (natural range <>) of string_access_t;
  type string_access_vector_access_t is access string_access_vector_t;

  type extstring_access_t is access string(1 to integer'high);
  type extstring_access_vector_t is array (natural range <>) of extstring_access_t;
  type extstring_access_vector_access_t is access extstring_access_vector_t;

  alias byte_vector_access_t is string_access_t;
  alias byte_vector_access_vector_t is string_access_vector_t;
  alias byte_vector_access_vector_access_t is string_access_vector_access_t;

  alias extbytevec_access_t is extstring_access_t;
  alias extbytevec_access_vector_t is extstring_access_vector_t;
  alias extbytevec_access_vector_access_t is extstring_access_vector_access_t;

  type integer_vector_t is array (natural range <>) of integer;
  type integer_vector_access_t is access integer_vector_t;
  type integer_vector_access_vector_t is array (natural range <>) of integer_vector_access_t;
  type integer_vector_access_vector_access_t is access integer_vector_access_vector_t;

  type extintvec_access_t is access integer_vector_t(0 to integer'high / 2 - 1);
  type extintvec_access_vector_t is array (natural range <>) of extintvec_access_t;
  type extintvec_access_vector_access_t is access extintvec_access_vector_t;
end package;
