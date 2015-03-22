-- Message types for card shuffler testbench
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.string_ops.all;

library com_lib;
use com_lib.com_codec_pkg.all;

use work.msg_types_pkg.all;

package codecs_pkg is
  function encode (
    constant data : rank_t)
    return string;
  function decode (
    constant code : string)
    return rank_t;
  function encode (
    constant data : suit_t)
    return string;
  function decode (
    constant code : string)
    return suit_t;
  function encode (
    constant data : card_t)
    return string;
  function decode (
    constant code : string)
    return card_t;
  function encode (
    constant data : card_msg_type_t)
    return string;
  function decode (
    constant code : string)
    return card_msg_type_t;
  function encode (
    constant data : card_msg_t)
    return string;
  function decode (
    constant code : string)
    return card_msg_t;
  function load (
    constant card : card_t)
    return string;
  function received (
    constant card : card_t)
    return string;
  function encode (
    constant data : reset_msg_type_t)
    return string;
  function decode (
    constant code : string)
    return reset_msg_type_t;
  function encode (
    constant data : reset_msg_t)
    return string;
  function decode (
    constant code : string)
    return reset_msg_t;
  function reset_shuffler
    return string;
  function encode (
    constant data : request_msg_type_t)
    return string;
  function decode (
    constant code : string)
    return request_msg_type_t;
  function encode (
    constant data : request_msg_t)
    return string;
  function decode (
    constant code : string)
    return request_msg_t;
  function get_status (
    constant n_received : natural)
    return string;
  function encode (
    constant data : reply_msg_type_t)
    return string;
  function decode (
    constant code : string)
    return reply_msg_type_t;
  function encode (
    constant data : reply_msg_t)
    return string;
  function decode (
    constant code : string)
    return reply_msg_t;
  function get_status_reply (
    constant checksum_match : boolean)
    return string;

  alias encode_reply_msg_t is encode[reply_msg_t return string];
  alias decode_reply_msg_t is decode[string return reply_msg_t];
  alias encode_reply_msg_type_t is encode[reply_msg_type_t return string];
  alias decode_reply_msg_type_t is decode[string return reply_msg_type_t];
  alias encode_request_msg_t is encode[request_msg_t return string];
  alias decode_request_msg_t is decode[string return request_msg_t];
  alias encode_request_msg_type_t is encode[request_msg_type_t return string];
  alias decode_request_msg_type_t is decode[string return request_msg_type_t];
  alias encode_reset_msg_t is encode[reset_msg_t return string];
  alias decode_reset_msg_t is decode[string return reset_msg_t];
  alias encode_reset_msg_type_t is encode[reset_msg_type_t return string];
  alias decode_reset_msg_type_t is decode[string return reset_msg_type_t];
  alias encode_card_msg_t is encode[card_msg_t return string];
  alias decode_card_msg_t is decode[string return card_msg_t];
  alias encode_card_msg_type_t is encode[card_msg_type_t return string];
  alias decode_card_msg_type_t is decode[string return card_msg_type_t];
  alias encode_card_t is encode[card_t return string];
  alias decode_card_t is decode[string return card_t];
  alias encode_suit_t is encode[suit_t return string];
  alias decode_suit_t is decode[string return suit_t];
  alias encode_rank_t is encode[rank_t return string];
  alias decode_rank_t is decode[string return rank_t];

end package codecs_pkg;

package body codecs_pkg is
  function encode (
    constant data : rank_t)
    return string is
  begin
    return rank_t'image(data);
  end function encode;

  function decode (
    constant code : string)
    return rank_t is
  begin
    return rank_t'value(code);
  end function decode;

  function encode (
    constant data : suit_t)
    return string is
  begin
    return suit_t'image(data);
  end function encode;

  function decode (
    constant code : string)
    return suit_t is
  begin
    return suit_t'value(code);
  end function decode;

  function encode (
    constant data : card_t)
    return string is
  begin
    return create_group(encode(data.rank), encode(data.suit));
  end function encode;

  function decode (
    constant code : string)
    return card_t is
    variable ret_val : card_t;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 2, length);
    ret_val.rank := decode(elements.all(0).all);
    ret_val.suit := decode(elements.all(1).all);
    deallocate_elements(elements);
    
    return ret_val;    
  end function decode;

  function encode (
    constant data : card_msg_type_t)
    return string is
  begin
    return card_msg_type_t'image(data);
  end function encode;

  function decode (
    constant code : string)
    return card_msg_type_t is
  begin
    return card_msg_type_t'value(code);
  end function decode;

  function encode (
    constant data : card_msg_t)
    return string is
  begin
    return create_group(encode(data.msg_type), encode(data.card));
  end function encode;

  function decode (
    constant code : string)
    return card_msg_t is
    variable ret_val : card_msg_t;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 2, length);
    ret_val.msg_type := decode(elements.all(0).all);
    ret_val.card := decode(elements.all(1).all);
    deallocate_elements(elements);
    
    return ret_val;    
  end function decode;

  function load (
    constant card : card_t)
    return string is
  begin
    return create_group(encode(card_msg_type_t'(load)), encode(card));
  end function load;

  function received (
    constant card : card_t)
    return string is
  begin
    return create_group(encode(card_msg_type_t'(received)), encode(card));
  end function received;
  
  function encode (
    constant data : reset_msg_type_t)
    return string is
  begin
    return reset_msg_type_t'image(data);
  end function encode;

  function decode (
    constant code : string)
    return reset_msg_type_t is
  begin
    return reset_msg_type_t'value(code);
  end function decode;

  function encode (
    constant data : reset_msg_t)
    return string is
  begin
    return create_group(encode(data.msg_type));
  end function encode;

  function decode (
    constant code : string)
    return reset_msg_t is
    variable ret_val : reset_msg_t;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 1, length);
    ret_val.msg_type := decode(elements.all(0).all);
    deallocate_elements(elements);
    
    return ret_val;    
  end function decode;

  function reset_shuffler
    return string is
  begin
    return create_group(encode(reset_msg_type_t'(reset_shuffler)));
  end function reset_shuffler;

  function encode (
    constant data : request_msg_type_t)
    return string is
  begin
    return request_msg_type_t'image(data);
  end function encode;

  function decode (
    constant code : string)
    return request_msg_type_t is
  begin
    return request_msg_type_t'value(code);
  end function decode;

  function encode (
    constant data : request_msg_t)
    return string is
  begin
    return create_group(encode(data.msg_type), encode(data.n_received));
  end function encode;

  function decode (
    constant code : string)
    return request_msg_t is
    variable ret_val : request_msg_t;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 2, length);
    ret_val.msg_type := decode(elements.all(0).all);
    ret_val.n_received := decode(elements.all(1).all);
    deallocate_elements(elements);
    
    return ret_val;    
  end function decode;

  function get_status (
    constant n_received : natural)
    return string is
  begin
    return create_group(encode(request_msg_type_t'(get_status)), encode(n_received));
  end function get_status;

  function encode (
    constant data : reply_msg_type_t)
    return string is
  begin
    return reply_msg_type_t'image(data);
  end function encode;

  function decode (
    constant code : string)
    return reply_msg_type_t is
  begin
    return reply_msg_type_t'value(code);
  end function decode;

  function encode (
    constant data : reply_msg_t)
    return string is
  begin
    return create_group(encode(data.msg_type), encode(data.checksum_match));
  end function encode;

  function decode (
    constant code : string)
    return reply_msg_t is
    variable ret_val : reply_msg_t;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 2, length);
    ret_val.msg_type := decode(elements.all(0).all);
    ret_val.checksum_match := decode(elements.all(1).all);
    deallocate_elements(elements);
    
    return ret_val;    
  end function decode;

  function get_status_reply (
    constant checksum_match : boolean)
    return string is
  begin
    return create_group(encode(reply_msg_type_t'(get_status_reply)), encode(checksum_match));
  end function get_status_reply;    
end package body codecs_pkg;
