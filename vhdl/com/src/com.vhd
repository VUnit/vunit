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
  type subscriber_item_t;
  type subscriber_item_ptr_t is access subscriber_item_t;
  type subscriber_item_t is record
    actor          : actor_t;
    next_item : subscriber_item_ptr_t;
  end record subscriber_item_t;
  type actor_item_t is record
    actor : actor_t;
    name : line;
    deferred_creation : boolean;
    inbox : inbox_t;
    reply_stash : envelope_ptr_t;
    subscribers : subscriber_item_ptr_t;
  end record actor_item_t;
  type actor_item_array_t is array (natural range <>) of actor_item_t;
  type actor_item_array_ptr_t is access actor_item_array_t;

  type messenger_t is protected body
    variable empty_inbox_c : inbox_t := (null, null);
    variable null_actor_item_c : actor_item_t := (null_actor_c, null, false, empty_inbox_c, null, null);
    impure function init_actors
      return actor_item_array_ptr_t is
      variable ret_val : actor_item_array_ptr_t;
    begin
      ret_val := new actor_item_array_t(0 to 0);
      ret_val(0) := null_actor_item_c;

      return ret_val;
    end function init_actors;
    variable actors : actor_item_array_ptr_t := init_actors;
    variable next_message_id : message_id_t := no_message_id_c + 1;

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
      actors(actors'length - 1) := ((id => actors'length - 1), new string'(name), deferred_creation, empty_inbox_c, null, null);
      
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

    impure function unknown_actor (
      constant actor : actor_t)
      return boolean is
    begin
      if (actor.id = 0) or (actor.id > actors'length - 1) then
        return true;
      elsif actors(actor.id).actor = null_actor_c then
        return true;
      end if;

      return false;
    end function unknown_actor;

    procedure destroy (
      variable actor : inout actor_t;
      variable status  : out   com_status_t) is
      variable envelope : envelope_ptr_t;
      variable item : subscriber_item_ptr_t;
      variable unsubscribe_status : com_status_t;
    begin
      if unknown_actor(actor) then
        status := unknown_actor_error;
        return;
      end if;

      while actors(actor.id).inbox.first_envelope /= null loop
        envelope := actors(actor.id).inbox.first_envelope;
        actors(actor.id).inbox.first_envelope := envelope.next_envelope;        
        deallocate(envelope.message.payload);
        deallocate(envelope);
      end loop;

      while actors(actor.id).subscribers /= null loop
        item := actors(actor.id).subscribers;
        actors(actor.id).subscribers := item.next_item;        
        deallocate(item);
      end loop;

      for i in actors'range loop
        unsubscribe(actor, actors(i).actor, unsubscribe_status);
      end loop;
      
      deallocate(actors(actor.id).name);
      actors(actor.id) := null_actor_item_c;
      actor            := null_actor_c;
    end;

    procedure reset_messenger is
      variable status  : com_status_t;
    begin
      for i in actors'range loop
        if actors(i).actor /= null_actor_c then
          destroy(actors(i).actor, status);
        end if;
      end loop;
      deallocate(actors);
      actors := init_actors;
      next_message_id := no_message_id_c + 1;
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
      constant request_id : in message_id_t;
      constant payload  : in    string;
      variable receipt   : out  receipt_t) is
      variable envelope : envelope_ptr_t;
    begin
      receipt.status := ok;
      receipt.id := no_message_id_c;
      if unknown_actor(receiver) then
        receipt.status := unknown_receiver_error;
      end if;

      if receipt.status = ok then
        receipt.id := next_message_id;
        envelope := new envelope_t;
        envelope.message.sender := sender;
        envelope.message.id := next_message_id;
        envelope.message.request_id := request_id;
        write(envelope.message.payload, payload);
        next_message_id := next_message_id + 1;
        
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

    impure function find_and_stash_reply_message (
      constant actor : actor_t;
      constant request_id : message_id_t)
      return boolean is
      variable envelope : envelope_ptr_t := actors(actor.id).inbox.first_envelope;
      variable previous_envelope : envelope_ptr_t := null;
    begin
      while envelope /= null loop
        if envelope.message.request_id = request_id then
          actors(actor.id).reply_stash := envelope;
          if previous_envelope /= null then
            previous_envelope.next_envelope := envelope.next_envelope;
          else
            actors(actor.id).inbox.first_envelope := envelope.next_envelope;
          end if;
          if actors(actor.id).inbox.first_envelope = null then
            actors(actor.id).inbox.last_envelope := null;
          end if;
          return true;
        end if;
        previous_envelope := envelope;
        envelope := envelope.next_envelope;
      end loop;

      return false;
    end function find_and_stash_reply_message;

    procedure clear_reply_stash (
      constant actor : in actor_t) is
    begin
      deallocate(actors(actor.id).reply_stash.message.payload);
      deallocate(actors(actor.id).reply_stash);
    end procedure clear_reply_stash;

    impure function has_reply_stash_message (
      constant actor : actor_t;
      constant request_id : message_id_t := no_message_id_c)
      return boolean is
    begin
      if request_id = no_message_id_c then
        return actors(actor.id).reply_stash /= null;
      elsif actors(actor.id).reply_stash /= null then
        return actors(actor.id).reply_stash.message.request_id = request_id;
      else
        return false;
      end if;
    end function has_reply_stash_message;

    impure function get_reply_stash_message_payload (
      constant actor : actor_t)
      return string is
      variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
    begin
      if envelope /= null then
        return envelope.message.payload.all;
      else
        return "";
      end if;
    end;

    impure function get_reply_stash_message_sender (
      constant actor : actor_t)
      return actor_t is
      variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
    begin
      if envelope /= null then
        return envelope.message.sender;
      else
        return null_actor_c;
      end if;
    end;

    impure function get_reply_stash_message_id (
      constant actor : actor_t)
      return message_id_t is
      variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
    begin
      if envelope /= null then
        return envelope.message.id;
      else
        return no_message_id_c;
      end if;
    end;
  
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

    impure function get_first_message_id (
      constant actor : actor_t)
      return message_id_t is
    begin
      if actors(actor.id).inbox.first_envelope /= null then
        return actors(actor.id).inbox.first_envelope.message.id;
      else
        return no_message_id_c;
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

  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher : in  actor_t;
    variable status    : out com_status_t) is
    variable new_subscriber, item : subscriber_item_ptr_t;
  begin
    if unknown_actor(subscriber) then
      status := unknown_subscriber_error;
    elsif unknown_actor(publisher) then
      status := unknown_publisher_error;
    end if;

    item := actors(publisher.id).subscribers;
    while item /= null loop
      exit when item.actor = subscriber;
      item := item.next_item;
    end loop;
    if item /= null then
      status := already_a_subscriber_error;
      return;
    end if;

    new_subscriber := new subscriber_item_t'(subscriber, actors(publisher.id).subscribers);
    actors(publisher.id).subscribers := new_subscriber;
    status := ok;
  end procedure subscribe;

  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher : in  actor_t;
    variable status    : out com_status_t) is
    variable item, previous_item : subscriber_item_ptr_t;
  begin
    if unknown_actor(subscriber) then
      status := unknown_subscriber_error;
    elsif unknown_actor(publisher) then
      status := unknown_publisher_error;
    end if;

    status := not_a_subscriber_error;
    item := actors(publisher.id).subscribers;
    previous_item := null;
    while item /= null loop
      if item.actor = subscriber then
        status := ok;
        if previous_item = null then
          actors(publisher.id).subscribers := item.next_item;
        else
          previous_item.next_item := item.next_item;
        end if;
        deallocate(item);
        exit;
      end if;
      previous_item := item;
      item := item.next_item;
    end loop;
  end procedure unsubscribe;

  procedure publish (
    constant sender   : in    actor_t;
    constant payload  : in    string;
    variable status   : out   com_status_t) is
    variable receipt : receipt_t;
    variable subscriber_item : subscriber_item_ptr_t;
  begin
    status := ok;
    if unknown_actor(sender) then
      status := unknown_publisher_error;
      return;
    end if;

    subscriber_item := actors(sender.id).subscribers;
    while subscriber_item /= null loop
      send(sender, subscriber_item.actor, no_message_id_c, payload, receipt);
      if receipt.status /= ok then
        status := unknown_subscriber_error;
      end if;
      subscriber_item := subscriber_item.next_item;
    end loop;
  end;
  
  end protected body;

  -----------------------------------------------------------------------------
  
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
    variable status  : out   com_status_t) is
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
    variable receipt   : out  receipt_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender);
    send(net, receiver, message, receipt);    
  end;
  
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt   : out  receipt_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload);
    send(net, receiver, message, receipt);    
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    variable receipt   : out  receipt_t;
    constant keep_message : in boolean := false) is
    variable sender : actor_t := null_actor_c;
  begin
    if message = null then
      receipt.status := null_message_error;
      return;
    end if;
    messenger.send(message.sender, receiver, no_message_id_c, message.payload.all, receipt);
    if receipt.status = ok then
      net <= network_event;
      wait for 0 ns;
      net <= idle_network;
    end if;
    if not keep_message then
      delete(message);
    end if;
  end;

  procedure reply (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant request_id : in message_id_t;
    constant payload  : in    string := "";
    variable receipt   : out  receipt_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender, request_id);
    reply(net, receiver, message, receipt);    
  end;

  procedure reply (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant request_id : in message_id_t;
    constant payload  : in    string := "";
    variable receipt   : out  receipt_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, request_id => request_id);
    reply(net, receiver, message, receipt);    
  end;

  procedure reply (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    variable receipt   : out  receipt_t;
    constant keep_message : in boolean := false) is 
  begin
    if message = null then
      receipt.status := null_message_error;
      return;
    end if;
    messenger.send(message.sender, receiver, message.request_id, message.payload.all, receipt);
    if receipt.status = ok then
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
    variable status : out com_status_t;
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
  
  procedure wait_for_reply_stash_message (
    signal net        : in network_t;
    constant receiver : in actor_t;
    constant request_id : in message_id_t;
    variable status : out com_status_t;
    constant receive_timeout : in time := max_timeout_c) is
  begin
    if messenger.deferred(receiver) then
      status := deferred_receiver_error;
    else
      status := ok;
      if messenger.has_reply_stash_message(receiver, request_id) then
        return;
      elsif messenger.find_and_stash_reply_message(receiver, request_id) then
        return;
      else
        wait on net until messenger.find_and_stash_reply_message(receiver, request_id) for receive_timeout;
        if not messenger.has_reply_stash_message(receiver, request_id) then
          status := timeout;
        end if;
      end if;
    end if;
  end procedure wait_for_reply_stash_message;
  
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
    message := new message_t;
    message.status := null_message_error;
    if messenger.has_messages(receiver) then
      message.status := ok;
      message.id := messenger.get_first_message_id(receiver);
      message.sender := messenger.get_first_message_sender(receiver);
      write(message.payload, messenger.get_first_message_payload(receiver));
      if delete_from_inbox then
        messenger.delete_first_envelope(receiver);
      end if;
    end if;

    return message;
  end function get_message;
    
  impure function get_reply_stash_message (
    constant receiver : actor_t;
    constant clear_reply_stash : in boolean := true)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message := new message_t;
    message.status := null_message_error;
    if messenger.has_reply_stash_message(receiver) then
      message.status := ok;
      message.id := messenger.get_reply_stash_message_id(receiver);
      message.sender := messenger.get_reply_stash_message_sender(receiver);
      write(message.payload, messenger.get_reply_stash_message_payload(receiver));
      if clear_reply_stash then
        messenger.clear_reply_stash(receiver);
      end if;
    end if;

    return message;
  end function get_reply_stash_message;
  
  procedure receive (
    signal net        : in network_t;
    constant receiver : actor_t;
    variable message : inout message_ptr_t;
    constant timeout : in time := max_timeout_c) is
    variable status : com_status_t;    
  begin
    if message /= null then
      delete(message);
    end if;
    wait_for_messages(net, receiver, status, timeout);
    if status = ok then
      message := get_message(receiver);
    else
      message := new message_t;
      message.status := status;
    end if;
  end;

  procedure receive_reply (
    signal net        : in network_t;
    constant receiver : actor_t;
    constant request_id : in message_id_t;
    variable message : inout message_ptr_t;
    constant timeout : in time := max_timeout_c) is
    variable status : com_status_t;    
  begin
    if message /= null then
      delete(message);
    end if;
    wait_for_reply_stash_message(net, receiver, request_id, status, timeout);
    if status = ok then
      message := get_reply_stash_message(receiver);
    else
      message := new message_t;
      message.status := status;
    end if;
  end;
  
  function compose (
    constant payload : string := "";
    constant sender  : actor_t := null_actor_c;
    constant request_id : in message_id_t := no_message_id_c)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message := new message_t;
    message.sender := sender;
    message.request_id := request_id;
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
    variable status    : out com_status_t) is
  begin
    messenger.subscribe(subscriber, publisher, status);
  end procedure subscribe;

  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher : in  actor_t;
    variable status    : out com_status_t) is
  begin
    messenger.unsubscribe(subscriber, publisher, status);
  end procedure unsubscribe;

  procedure publish (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   com_status_t) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender);
    publish(net, message, status);    
  end;

  procedure publish (
    signal net        : inout network_t;
    variable message  : inout message_ptr_t;
    variable status   : out   com_status_t;
    constant keep_message : in boolean := false) is
  begin
    if message = null then
      status := null_message_error;
      return;
    end if;
    messenger.publish(message.sender, message.payload.all, status);
    net <= network_event;
    wait for 0 ns;
    net <= idle_network;
    if not keep_message then
      delete(message);
    end if;
  end;

end package body com_pkg;

