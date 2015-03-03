-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package body com_pkg is
  type actor_list_item_t;
  type actor_list_item_ptr_t is access actor_list_item_t;
  type actor_list_item_t is record
    actor      : actor_t;
    deferred_creation : boolean;
    name : line;
    next_item : actor_list_item_ptr_t;
  end record actor_list_item_t;

  type messenger_t is protected body
    variable actors : actor_list_item_ptr_t := null;
    variable next_actor_id : integer := 0;
    variable n_actors : natural := 0;

    impure function find_actor (
      constant name : string)    
      return actor_t is
      variable item : actor_list_item_ptr_t := actors;
    begin
      while item /= null loop
        if item.name.all = name then
          return item.actor;
        end if;
        item := item.next_item;
      end loop;

      return null_actor_c;
    end;

    impure function create_actor (
      constant name : string := "";
      constant deferred_creation : in boolean := false)
      return actor_t is
      variable item : actor_list_item_ptr_t;
    begin
      item := new actor_list_item_t;
      item.actor.id := next_actor_id;
      write(item.name, name);
      item.deferred_creation := deferred_creation;
      item.next_item := actors;
      actors := item;

      next_actor_id := next_actor_id + 1;
      n_actors := n_actors + 1;
      
      return item.actor;
    end function;
                                
    impure function find (
      constant name : string;
      constant enable_deferred_creation : boolean := true)    
      return actor_t is
      variable actor : actor_t := find_actor(name);
    begin
      if (actor = null_actor_c) and enable_deferred_creation then
        return create_actor(name, true);
      else
        return actor;
      end if;
    end;
            
    impure function create (
      constant name : string := "")
      return actor_t is
      variable actor : actor_t := find_actor(name);
    begin
      if (actor = null_actor_c) then
        return create_actor(name);
      else
        return actor;
      end if;
    end;
  
    impure function deferred_creation (
      constant actor : actor_t)
      return deferred_creation_status_t is
      variable item : actor_list_item_ptr_t := actors;
    begin
      while item /= null loop
        if item.actor = actor then
          if item.deferred_creation then
            return deferred;
          else
            return not_deferred;
          end if;
        end if;
        item := item.next_item;
      end loop;
      
      return unknown_actor_error;
    end function deferred_creation;
  
    procedure destroy (
      variable actor : inout actor_t;
      variable status  : out   actor_destroy_status_t) is
      variable item : actor_list_item_ptr_t := actors;
      variable previous_item : actor_list_item_ptr_t := null;
    begin
      while item /= null loop
        if item.actor = actor then
          if previous_item /= null then
            previous_item.next_item := item.next_item;
          else
            actors := item.next_item;
          end if;
          deallocate(item.name);
          deallocate(item);
          actor :=null_actor_c;
          n_actors := n_actors - 1;
          status := destroy_ok;
          return;
        end if;
        previous_item := item;
        item := item.next_item;
      end loop;
      status := unknown_actor_error;
    end;

    procedure reset_messenger is
      variable item : actor_list_item_ptr_t := actors;
      variable previous_item : actor_list_item_ptr_t := null;
    begin
      actors := null;
      while item /= null loop
        previous_item := item;
        item := item.next_item;
        deallocate(previous_item.name);
        deallocate(previous_item);
      end loop;
      n_actors := 0;
      next_actor_id := 0;
    -- TODO: Deallocate messages when implemented
    end;

    impure function num_of_actors
      return natural is
    begin
      return n_actors;
    end;

    impure function num_of_deferred_creations
      return natural is
      variable item : actor_list_item_ptr_t := actors;
      variable n_deferred_actors : natural := 0;
    begin
      while item /= null loop
        if item.deferred_creation then
          n_deferred_actors := n_deferred_actors + 1;
        end if;
        item := item.next_item;
      end loop;

      return n_deferred_actors;
    end;
  
  end protected body;

  shared variable messenger : messenger_t;
  
  impure function create (
    constant name : string := "")
    return actor_t is
  begin
    return messenger.create(name);
  end;
  
  impure function find (
    constant name : string;
    constant enable_deferred_creation : boolean := true)    
    return actor_t is
  begin
    return messenger.find(name, enable_deferred_creation);
  end;

  impure function deferred_creation (
    constant actor : actor_t)
    return deferred_creation_status_t is
  begin
    return messenger.deferred_creation(actor);
  end function deferred_creation;

  procedure destroy (
    variable actor : inout actor_t;
    variable status  : out   actor_destroy_status_t) is
  begin
    messenger.destroy(actor, status);
  end;

  procedure reset_messenger is
  begin
    messenger.reset_messenger;
  end;

  impure function num_of_actors
    return natural is
  begin
    return messenger.num_of_actors;
  end;
  
  impure function num_of_deferred_creations
    return natural is
  begin
    return messenger.num_of_deferred_creations;
  end;
  
end package body com_pkg;

