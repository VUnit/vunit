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
  generic (
    runner_cfg : string);
end entity tb_card_shuffler;

architecture test_fixture of tb_card_shuffler is
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '0';
  signal input_card   : card_bus_t;
  signal input_valid  : std_logic := '0';
  signal output_card  : card_bus_t;
  signal output_valid : std_logic;
  constant n_decks    : natural   := 1;

  function slv_to_card (
    constant slv : card_bus_t)
    return card_t is
  begin
    return (rank_t'val(to_integer(unsigned(slv(5 downto 2)))),
            suit_t'val(to_integer(unsigned(slv(1 downto 0)))));
  end function slv_to_card;
begin
  test_runner : process
    constant self    : actor_t := create("test runner");
    variable reply   : message_ptr_t;
    variable receipt : receipt_t;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test that the cards in the deck are shuffled") then
        for i in 1 to n_decks loop
          -- reset_shuffler_msg is an alias for reset_shuffler which must be
          -- used with Aldec's simulators to avoid that this function call
          -- without parameters is confused with the enumeration literal in
          -- reset_msg_type_t with the same name.
          publish(net, self, reset_shuffler_msg);
          for r in ace to king loop
            for s in spades to clubs loop
              publish(net, self, load((r, s)));
            end loop;
          end loop;
          request(net, self, find("scoreboard"), get_status(52), reply);
          check_true(decode(reply.payload.all).matching_cards, "Cards loaded and received differ");
          check_false(decode(reply.payload.all).checksum_match, "Identical deck after shuffling");
        end loop;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 500 ms);

  clk <= not clk after 5 ns;

  card_shuffler : entity shuffler_lib.card_shuffler
    port map (
      clk          => clk,
      rst          => rst,
      input_card   => input_card,
      input_valid  => input_valid,
      output_card  => output_card,
      output_valid => output_valid);

  driver : process is
    constant self     : actor_t := create("driver");
    variable message  : message_ptr_t;
    variable card_msg : card_msg_t;
    variable status : com_status_t;
  begin
    subscribe(self, find("test runner"));
    loop
      wait until rising_edge(clk);
      wait_for_message(net, self, status, 0 ns);
      if status = ok then
        message := get_message(self);
        case get_msg_type(message.payload.all) is
          when reset_shuffler =>
            rst         <= '1';
            input_valid <= '0';
            wait until rising_edge(clk);
            rst         <= '0';
          when load =>
            card_msg    := decode(message.payload.all);
            input_valid <= '1';
            input_card  <= card_to_slv(card_msg.card);
          when others => null;
        end case;
      else
        input_valid <= '0';
      end if;
    end loop;
  end process driver;

  monitor : process is
    constant self : actor_t := create("monitor");
  begin
    wait until rising_edge(clk);
    if output_valid = '1' then
      publish(net, self, received(slv_to_card(output_card)));
    end if;
  end process monitor;

  scoreboard : entity work.scoreboard;

end test_fixture;
