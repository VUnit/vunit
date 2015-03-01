-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package body com_pkg is
  impure function create (
    constant name : string := "")
    return actor_t is
  begin
    return null_actor_c;
  end;
  
  impure function find (
    constant name : string;
    constant enable_deferred_creation : boolean := true)    
    return actor_t is
  begin
    return null_actor_c;
  end;

  function deferred_creation (
    constant actor : actor_t)
    return boolean is
  begin
    return false;
  end function deferred_creation;

  procedure destroy (
    variable actor_t : inout actor_t;
    variable status  : out   actor_destroy_status_t) is
  begin
    status := unknown_error;
  end;

  procedure destroy_all is
  begin
  end;

  impure function num_of_actors
    return natural is
  begin
    return 0;
  end;
  
  
end package body com_pkg;

