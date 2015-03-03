-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library com_lib;
use com_lib.com_types_pkg.all;

package com_pkg is
  type messenger_t is protected
    impure function find (
      constant name : string;
      constant enable_deferred_creation : boolean := true)    
      return actor_t;
    impure function create (
      constant name : string := "")
      return actor_t;
    impure function deferred_creation (
      constant actor : actor_t)
      return deferred_creation_status_t;
    procedure destroy (
      variable actor : inout actor_t;
      variable status  : out   actor_destroy_status_t);
    procedure reset_messenger;    
    impure function num_of_actors
      return natural;
  end protected;
  
  impure function create (
    constant name : string := "")
    return actor_t;
  impure function find (
    constant name : string;
    constant enable_deferred_creation : boolean := true)
    return actor_t;
  impure function deferred_creation (
    constant actor : actor_t)
    return deferred_creation_status_t;
  procedure destroy (
    variable actor : inout actor_t;
    variable status  : out   actor_destroy_status_t);
  procedure reset_messenger;
  impure function num_of_actors
    return natural;
end package;

  
