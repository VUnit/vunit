-- Message types for card shuffler testbench
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package msg_types_pkg is
  type rank_t is (ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king);
  type suit_t is (spades, hearts, diamonds, clubs);
  type card_t is record
    rank : rank_t;
    suit : suit_t;
  end record card_t;
  type scoreboard_status_t is record
    checksum_match : boolean;
    matching_cards : boolean;
  end record;
end package msg_types_pkg;
