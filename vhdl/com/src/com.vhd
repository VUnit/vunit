-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

package body com_pkg is
  type envelope_t;
  type envelope_ptr_t is access envelope_t;
  type envelope_t is record
    message : message_t;
    next_envelope : envelope_ptr_t;
  end record envelope_t;
  type inbox_t is record
    first_envelope       : envelope_ptr_t;
    last_envelope        : envelope_ptr_t;
  end record inbox_t;
  type actor_item_t is record
    actor : actor_t;
    name : line;
    deferred_creation : boolean;
    inbox : inbox_t;
  end record actor_item_t;
  type actor_item_array_t is array (natural range <>) of actor_item_t;
  type actor_item_array_ptr_t is access actor_item_array_t;

  type messenger_t is protected body
    variable empty_inbox_c : inbox_t := (null, null);
    variable null_actor_item_c : actor_item_t := (null_actor_c, null, false, empty_inbox_c);
    impure function init_actors
      return actor_item_array_ptr_t is
      variable ret_val : actor_item_array_ptr_t;
    begin
      ret_val := new actor_item_array_t(0 to 0);
      ret_val(0) := null_actor_item_c;

      return ret_val;
    end function init_actors;
    variable actors : actor_item_array_ptr_t := init_actors;

    impure function find_actor (
      constant name : string)    
      return actor_t is
      variable ret_val : actor_t;
    begin
      for i in actors'reverse_range loop
        ret_val := actors(i).actor;
        if actors(i).name /= null then
          exit when actors(i).name.all = name;
        end if;
      end loop;

      return ret_val;
    end;

    impure function create_actor (
      constant name : string := "";
      constant deferred_creation : in boolean := false)
      return actor_t is
      variable old_actors : actor_item_array_ptr_t;
    begin
      old_actors := actors;      
      actors := new actor_item_array_t(0 to actors'length);
      actors(0) := null_actor_item_c;
      for i in old_actors'range loop
        actors(i) := old_actors(i);
      end loop;
      deallocate(old_actors);
      actors(actors'length - 1) := ((id => actors'length - 1), new string'(name), deferred_creation, empty_inbox_c);
      
      return actors(actors'length - 1).actor;
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
      if actor = null_actor_c then
        actor := create_actor(name);
      elsif actors(actor.id).deferred_creation then
        actors(actor.id).deferred_creation := false;
      end if;

      return actor;
    end;
    
    procedure destroy (
      variable actor : inout actor_t;
      variable status  : out   actor_destroy_status_t) is
      variable envelope : envelope_ptr_t;
    begin
      if (actor.id >= actors'length) then
        status := unknown_actor_error;
        return;
      elsif actors(actor.id).actor = null_actor_c then
        status := unknown_actor_error;
        return;        
      end if;

      while actors(actor.id).inbox.first_envelope /= null loop
        envelope := actors(actor.id).inbox.first_envelope;
        actors(actor.id).inbox.first_envelope := envelope.next_envelope;        
        deallocate(envelope.message.payload);
        deallocate(envelope);
      end loop;
      deallocate(actors(actor.id).name);
      actors(actor.id) := null_actor_item_c;
      actor            := null_actor_c;
    end;

    procedure reset_messenger is
      variable status  : actor_destroy_status_t;
    begin
      for i in actors'range loop
        if actors(i).actor /= null_actor_c then
          destroy(actors(i).actor, status);
        end if;
      end loop;
      deallocate(actors);
      actors := init_actors;
    end;

    impure function num_of_actors
      return natural is
      variable n_actors : natural := 0;
    begin
      for i in actors'range loop
        if actors(i).actor /= null_actor_c then
          n_actors := n_actors + 1;
        end if;
      end loop;
      
      return n_actors;
    end;

    impure function deferred (
      constant actor : actor_t)
      return boolean is
    begin
      return actors(actor.id).deferred_creation;
    end function deferred;

    impure function num_of_deferred_creations
      return natural is
      variable n_deferred_actors : natural := 0;
    begin
      for i in actors'range loop
        if actors(i).deferred_creation then
          n_deferred_actors := n_deferred_actors + 1;
        end if;
      end loop;

      return n_deferred_actors;
    end;

    procedure send (
      constant sender   : in    actor_t;
      constant receiver : in    actor_t;
      constant payload  : in    string;
      variable status   : out   send_status_t) is
      variable envelope : envelope_ptr_t;
    begin
      status := ok;      
      if (receiver.id = 0) or (receiver.id > actors'length - 1) then
        status := unknown_receiver_error;
      elsif actors(receiver.id).actor = null_actor_c then
        status := unknown_receiver_error;
      end if;

      if status = ok then
        envelope := new envelope_t;
        envelope.message.sender := sender;
        write(envelope.message.payload, payload);
        
        if actors(receiver.id).inbox.last_envelope /= null then
          actors(receiver.id).inbox.last_envelope.next_envelope := envelope;
        else
          actors(receiver.id).inbox.first_envelope := envelope;
        end if;
        actors(receiver.id).inbox.last_envelope := envelope;
      end if;
    end;

    impure function has_messages (
      constant actor : actor_t)
      return boolean is
    begin
      return actors(actor.id).inbox.first_envelope /= null;
    end function has_messages;
  
    impure function get_first_message_payload (
      constant actor : actor_t)
      return string is
    begin
      if actors(actor.id).inbox.first_envelope /= null then
        return actors(actor.id).inbox.first_envelope.message.payload.all;
      else
        return "";
      end if;
    end;

    impure function get_first_message_sender (
      constant actor : actor_t)
      return actor_t is
    begin
      if actors(actor.id).inbox.first_envelope /= null then
        return actors(actor.id).inbox.first_envelope.message.sender;
      else
        return null_actor_c;
      end if;
    end;

    procedure delete_first_envelope (
      constant actor : in actor_t) is
      variable first_envelope : envelope_ptr_t := actors(actor.id).inbox.first_envelope;
    begin
      if first_envelope /= null then
        deallocate(first_envelope.message.payload);
        actors(actor.id).inbox.first_envelope := first_envelope.next_envelope;
        deallocate(first_envelope);
        if actors(actor.id).inbox.first_envelope = null then
          actors(actor.id).inbox.last_envelope := null;
        end if;
      end if;
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

  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   send_status_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender);
    send(net, receiver, message, status);    
  end;
  
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   send_status_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload);
    send(net, receiver, message, status);    
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    variable status   : out   send_status_t;
    constant keep_message : in boolean := false) is
    variable sender : actor_t := null_actor_c;
  begin
    if message = null then
      status := null_message_error;
      return;
    end if;
    messenger.send(message.sender, receiver, message.payload.all, status);
    if status = ok then
      net <= network_event;
      wait for 0 ns;
      net <= idle_network;
    end if;
    if not keep_message then
      delete(message);
    end if;
  end;

  procedure wait_for_messages (
    signal net        : in network_t;
    constant receiver : in actor_t;
    variable status : out receive_status_t;
    constant receive_timeout : in time := max_timeout_c) is
  begin
    if messenger.deferred(receiver) then
      status := deferred_receiver_error;
    else
      status := ok;
      if not messenger.has_messages(receiver) then
        wait on net until messenger.has_messages(receiver) for receive_timeout;
        if not messenger.has_messages(receiver) then
          status := timeout;
        end if;
      end if;
    end if;
  end procedure wait_for_messages;

  impure function has_messages (
    constant actor : actor_t)
    return boolean is
  begin
    return messenger.has_messages(actor);
  end function has_messages;
  
  impure function get_message (
    constant receiver : actor_t;
    constant delete_from_inbox : in boolean := true)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    if messenger.has_messages(receiver) then
      message := new message_t;
      message.sender := messenger.get_first_message_sender(receiver);
      write(message.payload, messenger.get_first_message_payload(receiver));
      if delete_from_inbox then
        messenger.delete_first_envelope(receiver);
      end if;
    end if;

    return message;
  end function get_message;
  
  procedure receive (
    signal net        : in network_t;
    constant receiver : actor_t;
    variable message : inout message_ptr_t;
    variable status : out receive_status_t;
    constant timeout : in time := max_timeout_c) is
  begin
    wait_for_messages(net, receiver, status, timeout);
    if message /= null then
      delete(message);
    end if;
    if status = ok then
      message := get_message(receiver);
    end if;
  end;

  function compose (
    constant payload : string := "";
    constant sender  : actor_t := null_actor_c)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message := new message_t;
    message.sender := sender;
    write(message.payload, payload);
    return message;
  end function compose;

  procedure delete (
    variable message : inout message_ptr_t) is
  begin
    if message /= null then
      deallocate(message.payload);
      deallocate(message);
    end if;
  end procedure delete;

  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher : in  actor_t;
    variable status    : out subscribe_status_t) is
  begin
    status := unknown_actor_error;
  end procedure subscribe;

  procedure publish (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   publish_status_t) is
  begin
    status := unknown_receiver_error;
  end;
  
  procedure publish (
    signal net        : inout network_t;
    constant payload  : in    string := "";
    variable status   : out   publish_status_t) is
  begin
    status := unknown_receiver_error;
  end;

  procedure publish (
    signal net        : inout network_t;
    variable message  : inout message_ptr_t;
    variable status   : out   publish_status_t;
    constant keep_message : in boolean := false) is
  begin
    status := unknown_receiver_error;
  end;
end package body com_pkg;

