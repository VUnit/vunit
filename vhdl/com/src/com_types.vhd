-- Common com types.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package com_types_pkg is
  type actor_t is record
    id : integer;
  end record actor_t;
  constant null_actor_c : actor_t := (id => integer'left);
  type actor_destroy_status_t is (destroy_ok, unknown_actor_error, unknown_error);
  type deferred_creation_status_t is (deferred, not_deferred, unknown_actor_error);
  
end package;
