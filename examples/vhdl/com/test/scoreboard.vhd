-- Test suite for card shuffler package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.textio.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.com_codec_pkg.all;
use vunit_lib.com_string_pkg.all;
use vunit_lib.com_debug_codec_builder_pkg.all;
use vunit_lib.com_std_codec_builder_pkg.all;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.msg_types_pkg.all;
use work.msg_codecs_pkg.all;

use work.tb_common_pkg.all;

entity scoreboard is
end entity scoreboard;

architecture behavioral of scoreboard is
begin
  main : process is
    variable self, requesting_actor               : actor_t;
    variable status                               : com_status_t;
    variable receipt                              : receipt_t;
    variable message                              : message_ptr_t;
    variable request_id                           : message_id_t;
    variable checkpoint                           : integer                 := -1;
    variable n_received                           : natural;
    variable card_msg                             : card_msg_t;
    variable received_checksum, loaded_checksum   : card_bus_t              := (others => '0');
    variable received_checksum2, loaded_checksum2 : card_bus_t              := (others => '0');
    variable received_cards, loaded_cards         : integer_vector(0 to 51) := (others => 0);
    procedure update_checksum (
      variable checksum : inout card_bus_t;
      constant card     : in    card_bus_t) is
    begin
      checksum := std_logic_vector(to_unsigned((to_integer(unsigned(checksum)) + to_integer(unsigned(card))) mod 64, 6));
    end procedure update_checksum;
    procedure update_card_log (
      variable card_log : inout integer_vector;
      constant card     : in    card_t) is
      variable index : natural;
    begin
      index           := rank_t'pos(card.rank) * 4 + suit_t'pos(card.suit);
      card_log(index) := card_log(index) + 1;
    end procedure update_card_log;
  begin
    self := create("scoreboard");
    subscribe(self, find("test runner"), status);
    subscribe(self, find("monitor"), status);
    loop
      receive(net, self, message);
      case get_msg_type(message.payload.all) is
        when reset_shuffler =>
          n_received         := 0;
          received_checksum  := (others => '0'); loaded_checksum := (others => '0');
          received_checksum2 := (others => '0'); loaded_checksum2 := (others => '0');
          received_cards     := (others => 0); loaded_cards := (others => 0);
        when load =>
          card_msg := decode(message.payload.all);
          update_checksum(loaded_checksum, card_to_slv(card_msg.card));
          update_checksum(loaded_checksum2, loaded_checksum);
          update_card_log(loaded_cards, card_msg.card);
        when received =>
          card_msg   := decode(message.payload.all);
          update_checksum(received_checksum, card_to_slv(card_msg.card));
          update_checksum(received_checksum2, received_checksum);
          update_card_log(received_cards, card_msg.card);
          n_received := n_received + 1;
        when get_status =>
          checkpoint       := decode(message.payload.all).checkpoint;
          requesting_actor := message.sender;
          request_id       := message.id;
        when others => null;
      end case;

      if n_received = checkpoint then
        reply(net, requesting_actor, request_id,
              get_status_reply((loaded_checksum = received_checksum) and (loaded_checksum2 = received_checksum2),
                               loaded_cards = received_cards),
              receipt);
      end if;
    end loop;
    wait;
  end process main;

end architecture behavioral;
