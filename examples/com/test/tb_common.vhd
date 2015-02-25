-- Test suite for card shuffler package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.msg_types_pkg.all;

package tb_common_pkg is
  subtype card_bus_t is std_logic_vector(5 downto 0);

  function card_to_slv (
    constant card : card_t)
    return std_logic_vector;
end package tb_common_pkg;

package body tb_common_pkg is
  function card_to_slv (
    constant card : card_t)
    return std_logic_vector is
    variable ret_val : card_bus_t;
  begin
    ret_val(5 downto 2) := std_logic_vector(to_unsigned(rank_t'pos(card.rank), 4));
    ret_val(1 downto 0) := std_logic_vector(to_unsigned(suit_t'pos(card.suit), 2));

    return ret_val;
  end function card_to_slv;
end package body tb_common_pkg;
