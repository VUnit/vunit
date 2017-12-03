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

library shuffler_lib;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.msg_types_pkg.all;
use work.msg_codecs_pkg.all;

use work.tb_common_pkg.all;

entity tb_card_shuffler is
  generic(
    runner_cfg : string);
end entity tb_card_shuffler;

architecture test_fixture of tb_card_shuffler is
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '0';
  signal input_card   : card_bus_t;
  signal input_valid  : std_logic := '0';
  signal output_card  : card_bus_t;
  signal output_valid : std_logic;
  constant n_decks    : natural   := 2;

  function slv_to_card(
    constant slv : card_bus_t) return card_t is
  begin
    return (rank_t'val(to_integer(unsigned(slv(5 downto 2)))),
            suit_t'val(to_integer(unsigned(slv(1 downto 0)))));
  end function slv_to_card;
begin
  test_runner : process
    constant self                        : actor_t := new_actor("test runner");
    variable msg, request_msg, reply_msg : msg_t;
    variable msg_type                    : msg_type_t;
    variable scoreboard_status           : scoreboard_status_t;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test that the cards in the deck are shuffled") then
        for i in 1 to n_decks loop
          msg := new_msg;
          push_msg_type(msg, reset_shuffler);
          publish(net, self, msg);

          for rank in ace to king loop
            for suit in spades to clubs loop
              msg := new_msg;
              push_msg_type(msg, load_card);
              push_card_t(msg, (rank, suit));
              publish(net, self, msg);
            end loop;
          end loop;

          request_msg       := new_msg;
          push_msg_type(request_msg, get_scoreboard_status);
          push_integer(request_msg, 52);
          request(net, find("scoreboard"), request_msg, reply_msg);
          msg_type          := pop_msg_type(reply_msg);
          scoreboard_status := pop(reply_msg);
          check_true(scoreboard_status.matching_cards, "Cards loaded and received differ");
          check_false(scoreboard_status.checksum_match, "Identical deck after shuffling");
        end loop;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 500 ms);

  clk <= not clk after 5 ns;

  card_shuffler : entity shuffler_lib.card_shuffler
    port map(
      clk          => clk,
      rst          => rst,
      input_card   => input_card,
      input_valid  => input_valid,
      output_card  => output_card,
      output_valid => output_valid);

  driver : process is
    constant self     : actor_t := new_actor("driver");
    variable card     : card_t;
    variable msg      : msg_t;
    variable msg_type : msg_type_t;
  begin
    subscribe(self, find("test runner"));
    loop
      wait until rising_edge(clk);
      input_valid <= '0';
      
      receive(net, self, msg);
      msg_type := pop_msg_type(msg);
      
      if msg_type = reset_shuffler then
        rst         <= '1';
        wait until rising_edge(clk);
        rst         <= '0';
      elsif msg_type = load_card then
        card        := pop(msg);
        input_valid <= '1';
        input_card  <= card_to_slv(card);
      end if;
    end loop;
  end process driver;

  monitor : process is
    constant self : actor_t := create("monitor");
    variable msg  : msg_t;
  begin
    wait until rising_edge(clk);
    if output_valid = '1' then
      msg := new_msg;
      push_msg_type(msg, received_card);
      push(msg, slv_to_card(output_card));
      publish(net, self, msg);
    end if;
  end process monitor;

  scoreboard : entity work.scoreboard
    ;

end test_fixture;
