-- Com common package provides functionality shared among the other packages
-- The package is private to com.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com
library ieee;
use ieee.std_logic_1164.all;

use work.com_messenger_pkg.all;
use work.com_types_pkg.all;
use work.com_support_pkg.all;

use std.textio.all;

package com_common_pkg is
  shared variable messenger : messenger_t;

  procedure notify (signal net : inout network_t);

  procedure wait_for_reply_stash_message (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    constant mailbox_name : in mailbox_name_t := inbox;
    constant request_id      : in    message_id_t;
    variable status          : out   com_status_t;
    constant timeout : in    time := max_timeout_c);

  impure function get_reply_stash_message (
    receiver : actor_t;
    clear_reply_stash : boolean := true)
    return message_ptr_t;

  impure function no_error_status (status : com_status_t; old_api : boolean := false) return boolean;
end package com_common_pkg;

package body com_common_pkg is
  procedure notify (signal net : inout network_t) is
  begin
    if net /= network_event then
      net <= network_event;
      wait until net = network_event;
      net <= idle_network;
    end if;
  end procedure notify;

  -- TODO: Don't stash when finding reply. Remove when getting it.
  procedure wait_for_reply_stash_message (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    constant mailbox_name : in mailbox_name_t := inbox;
    constant request_id      : in    message_id_t;
    variable status          : out   com_status_t;
    constant timeout : in    time := max_timeout_c) is
    variable started_with_full_inbox : boolean := false;
  begin
    check(not messenger.deferred(receiver), deferred_receiver_error);

    status                  := ok;
    if mailbox_name = inbox then
      started_with_full_inbox := messenger.is_full(receiver, inbox);
    end if;

    if messenger.has_reply_stash_message(receiver, request_id) then
      return;
    elsif messenger.find_and_stash_reply_message(receiver, request_id, mailbox_name) then
      if started_with_full_inbox then
        notify(net);
      end if;
      return;
    else
      wait on net until messenger.find_and_stash_reply_message(receiver, request_id, mailbox_name) for timeout;
      if not messenger.has_reply_stash_message(receiver, request_id) then
        status := work.com_types_pkg.timeout;
      elsif started_with_full_inbox then
        notify(net);
      end if;
    end if;
  end procedure wait_for_reply_stash_message;

  impure function get_reply_stash_message (
    receiver : actor_t;
    clear_reply_stash : boolean := true)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    check(messenger.has_reply_stash_message(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_reply_stash_message_id(receiver);
    message.request_id := messenger.get_reply_stash_message_request_id(receiver);
    message.sender     := messenger.get_reply_stash_message_sender(receiver);
    message.receiver   := receiver;
    write(message.payload, messenger.get_reply_stash_message_payload(receiver));
    if clear_reply_stash then
      messenger.clear_reply_stash(receiver);
    end if;

    return message;
  end function get_reply_stash_message;

  impure function no_error_status (status : com_status_t; old_api : boolean := false) return boolean is
  begin
    return (status = ok) or ((status = timeout) and messenger.timeout_is_allowed and old_api);
  end;

end package body com_common_pkg;
