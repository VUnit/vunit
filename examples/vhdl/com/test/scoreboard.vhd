-- Test suite for card shuffler package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use std.textio.all;

use work.msg_types_pkg.all;
use work.msg_codecs_pkg.all;

use work.tb_common_pkg.all;

entity scoreboard is
end entity scoreboard;

architecture behavioral of scoreboard is
begin
  main : process is
    constant self                                 : actor_t                 := new_actor("scoreboard");
    variable msg, reply_msg, request_msg          : msg_t;
    variable msg_type                             : msg_type_t;
    variable checkpoint                           : integer                 := -1;
    variable n_received                           : natural;
    variable card                                 : card_t;
    variable received_checksum, loaded_checksum   : card_bus_t              := (others => '0');
    variable received_checksum2, loaded_checksum2 : card_bus_t              := (others => '0');
    variable received_cards, loaded_cards         : integer_vector(0 to 51) := (others => 0);
    
    procedure update_checksum(
      variable checksum : inout card_bus_t;
      constant card     : in card_bus_t) is
    begin
      checksum := checksum + card;
    end procedure update_checksum;
    
    procedure update_card_log(
      variable card_log : inout integer_vector;
      constant card     : in card_t) is
      variable index : natural;
    begin
      index           := rank_t'pos(card.rank) * 4 + suit_t'pos(card.suit);
      card_log(index) := card_log(index) + 1;
    end procedure update_card_log;
  
  begin
    subscribe(self, find("test runner"));
    subscribe(self, find("monitor"));
    while true loop
      receive(net, self, msg);
      msg_type := pop_msg_type(msg);
      
      if msg_type = reset_shuffler then
        n_received         := 0;
        received_checksum  := (others => '0');
        loaded_checksum    := (others => '0');
        received_checksum2 := (others => '0');
        loaded_checksum2   := (others => '0');
        received_cards     := (others => 0);
        loaded_cards       := (others => 0);
      elsif msg_type = load_card then
        card := pop(msg);
        update_checksum(loaded_checksum, card_to_slv(card));
        update_checksum(loaded_checksum2, loaded_checksum);
        update_card_log(loaded_cards, card);
      elsif msg_type = received_card then
        card       := pop(msg);
        update_checksum(received_checksum, card_to_slv(card));
        update_checksum(received_checksum2, received_checksum);
        update_card_log(received_cards, card);
        n_received := n_received + 1;
      elsif msg_type = get_scoreboard_status then
        checkpoint  := pop(msg);
        request_msg := msg;
      end if;

      if n_received = checkpoint then
        reply_msg := new_msg;
        push_msg_type(reply_msg, scoreboard_status);
        push_scoreboard_status_t(reply_msg, ((loaded_checksum = received_checksum) and (loaded_checksum2 = received_checksum2), loaded_cards = received_cards));
        reply(net, request_msg, reply_msg);
      end if;
    end loop;
    wait;
  end process main;

end architecture behavioral;
