-- Common com types.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package com_types_pkg is
  subtype actor_t is integer;
  constant null_actor_c : integer := integer'left;
  type actor_destroy_status_t is (destroy_ok, unknown_actor_error, unknown_error);
end package;
