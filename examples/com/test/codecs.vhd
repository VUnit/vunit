-- Message types for card shuffler testbench
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.string_ops.all;

use work.msg_types_pkg.all;

package codecs_pkg is
    function load (
      constant card : card_t)
      return string;
    function received (
      constant card : card_t)
      return string;
    impure function decode (
      constant msg : string)
      return card_msg_t;
    
    function reset_shuffler
      return string;
    impure function decode (
      constant msg : string)
      return reset_msg_t;
    
    function get_status (
      constant n_received : natural)
      return string;
    impure function decode (
      constant msg : string)
      return request_msg_t;
    
    function get_status_reply (
      constant checksum_match : boolean)
      return string;
    impure function decode (
      constant msg : string)
      return reply_msg_t;
end package codecs_pkg;

package body codecs_pkg is
    function load (
      constant card : card_t)
      return string is
    begin
      return "load " & rank_t'image(card.rank) & " " & suit_t'image(card.suit);
    end function load;
    function received (
      constant card : card_t)
      return string is
    begin
      return "received " & rank_t'image(card.rank) & " " & suit_t'image(card.suit);
    end function received;
    impure function decode (
      constant msg : string)
      return card_msg_t is
      variable msg_split : lines_t;
      variable ret_val : card_msg_t;
    begin
      msg_split := split(msg, " ");
      ret_val.msg_type := card_msg_type_t'value(msg_split(0).all);
      ret_val.card.rank := rank_t'value(msg_split(1).all);
      ret_val.card.suit := suit_t'value(msg_split(2).all);
      return ret_val;
    end function decode;

    function reset_shuffler
      return string is
    begin
      return "reset_shuffler";
    end function reset_shuffler;
    impure function decode (
      constant msg : string)
      return reset_msg_t is
      variable msg_split : lines_t;
      variable ret_val : reset_msg_t;
    begin
      msg_split := split(msg, " ");
      ret_val.msg_type := reset_msg_type_t'value(msg_split(0).all);
      return ret_val;
    end function decode;

    function get_status (
      constant n_received : natural)
      return string is
    begin
      return "get_status " & natural'image(n_received);
    end function get_status;
    impure function decode (
      constant msg : string)
      return request_msg_t is
      variable msg_split : lines_t;
      variable ret_val : request_msg_t;
    begin
      msg_split := split(msg, " ");
      ret_val.msg_type := request_msg_type_t'value(msg_split(0).all);
      ret_val.n_received := natural'value(msg_split(1).all);
      return ret_val;
    end function decode;
    
    function get_status_reply (
      constant checksum_match : boolean)
      return string is
    begin
      return "get_status_reply " & boolean'image(checksum_match);
    end function get_status_reply;    
    impure function decode (
      constant msg : string)
      return reply_msg_t is
      variable msg_split : lines_t;
      variable ret_val : reply_msg_t;
    begin
      msg_split := split(msg, " ");
      ret_val.msg_type := reply_msg_type_t'value(msg_split(0).all);
      ret_val.checksum_match := boolean'value(msg_split(1).all);
      return ret_val;
    end function decode;
end package body codecs_pkg;
