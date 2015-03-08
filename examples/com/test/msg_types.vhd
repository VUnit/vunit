-- Message types for card shuffler testbench
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package msg_types_pkg is
  type rank_t is (ace, one, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king);
  type suit_t is (spades, hearts, diamonds, clubs);
  type card_t is record
    rank : rank_t;
    suit : suit_t;
  end record card_t;
  type card_msg_type_t is (load, received);
  type card_msg_t is record
    msg_type : card_msg_type_t;
    card     : card_t;
  end record card_msg_t;
  
  type reset_msg_type_t is (reset_shuffler);
  type reset_msg_t is record
    msg_type : reset_msg_type_t;
  end record reset_msg_t;
  
  type request_msg_type_t is (get_status);
  type request_msg_t is record
    msg_type : request_msg_type_t;
    n_received  : natural;
  end record request_msg_t;
  
  type reply_msg_type_t is (get_status_reply);
  type reply_msg_t is record
    msg_type : reply_msg_type_t;
    checksum_match : boolean;
  end record reply_msg_t;
end package msg_types_pkg;
