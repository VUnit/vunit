-- Test suite for card shuffler package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library com_lib;
use com_lib.com_pkg.all;
use com_lib.com_types_pkg.all;

library shuffler_lib;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.msg_types_pkg.all;
use work.codecs_pkg.all;

entity tb_card_shuffler is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity tb_card_shuffler;

architecture test_fixture of tb_card_shuffler is
  signal clk          : std_logic := '0';
  signal rst        : std_logic := '0';
  signal input_card   : std_logic_vector(5 downto 0);
  signal input_valid  : std_logic := '0';
  signal output_card  : std_logic_vector(5 downto 0);
  signal output_valid : std_logic;
    impure function msg_type (
      constant msg : string)
      return string is
      variable type_split : lines_t;
    begin
      type_split := split(msg, " ", 1);
      return type_split(0).all;
    end;
begin
  test_runner : process
    variable self, scoreboard : actor_t;
    variable message : message_ptr_t;
    variable status : com_status_t;
  begin
    checker_init(display_format => verbose,
                 file_name => join(output_path(runner_cfg), "error.csv"),
                 file_format => verbose_csv);    
    test_runner_setup(runner, runner_cfg);
    self := create("test runner");
    scoreboard := find("scoreboard");
    while test_suite loop
      if run("Test that the cards in the deck are shuffled") then
        publish(net, self, reset_shuffler, status);

        for r in 0 to 12 loop        
          for s in 0 to 3 loop
            publish(net, self, load((rank_t'val(r), suit_t'val(s))), status);
          end loop;
        end loop;

        send(net, self, scoreboard, get_status(52), status);
        wait_for_scoreboard_reply: loop 
          receive(net, self, message, status);
          if msg_type(message.payload.all) = "get_status_reply" then
            check_false(decode(message.payload.all).checksum_match, "Identical deck after shuffling");
            exit wait_for_scoreboard_reply;
          end if;
        end loop;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 5 ms);

  clk <= not clk after 5 ns;

  card_shuffler: entity shuffler_lib.card_shuffler
    port map (
      clk          => clk,
      rst        => rst,
      input_card   => input_card,
      input_valid  => input_valid,
      output_card  => output_card,
      output_valid => output_valid);

  driver: process is
      variable self : actor_t;
      variable message : message_ptr_t;
      variable status : com_status_t;
      variable msg : card_msg_t;
  begin
      self := create("driver");
      subscribe(self, find("test runner"), status);
      loop 
        receive(net, self, message, status);
        wait until rising_edge(clk);        
        if msg_type(message.payload.all) = "load" then
          msg := decode(message.payload.all);
          input_valid <= '1';
          input_card(5 downto 2) <= std_logic_vector(to_unsigned(rank_t'pos(msg.card.rank), 4));
          input_card(1 downto 0) <= std_logic_vector(to_unsigned(suit_t'pos(msg.card.suit), 2));
          wait until rising_edge(clk);
          input_valid <= '0';
        elsif msg_type(message.payload.all) = "reset_shuffler" then
          rst <= '1';
          wait until rising_edge(clk);
          rst <= '0';
        end if;
      end loop;
  end process driver;

  monitor: process is
    variable self : actor_t;
    variable status : com_status_t;
    variable received_card : card_t;
  begin
    self := create("monitor");
    loop 
      wait until rising_edge(clk);
      if output_valid = '1' then
        received_card := (rank_t'val(to_integer(unsigned(output_card(5 downto 2)))),
                          suit_t'val(to_integer(unsigned(output_card(1 downto 0)))));
        publish(net, self, received(received_card), status);
      end if;
    end loop;
  end process monitor;

  scoreboard: process is
    variable self, client : actor_t;
    variable status : com_status_t;
    variable message : message_ptr_t;
    variable status_point : integer := -1;
    variable n_received, n_loaded, index : natural;
    variable received_msg, load_msg : card_msg_t;
    variable received_checksum, loaded_checksum : integer := 0;
  begin
    self := create("scoreboard");
    subscribe(self, find("monitor"), status);
    subscribe(self, find("test runner"), status);
    loop 
        receive(net, self, message, status);
        if msg_type(message.payload.all) = "reset_shuffler" then
          n_received := 0;
          n_loaded := 0;
          received_checksum := 0;
          loaded_checksum := 0;
        elsif msg_type(message.payload.all) = "load" then
          load_msg := decode(message.payload.all);
          index := rank_t'pos(load_msg.card.rank) * 4 +suit_t'pos(load_msg.card.suit);
          loaded_checksum := loaded_checksum + (index * n_loaded);
          n_loaded := n_loaded + 1;
        elsif msg_type(message.payload.all) = "received" then
          received_msg := decode(message.payload.all);
          index := rank_t'pos(received_msg.card.rank) * 4 +suit_t'pos(received_msg.card.suit);
          received_checksum := received_checksum + (index * n_received);
          n_received := n_received + 1;
        elsif msg_type(message.payload.all) = "get_status" then
          status_point := decode(message.payload.all).n_received;
          client := message.sender;
        end if;

        if n_received = status_point then
            send(net, client, get_status_reply(loaded_checksum = received_checksum), status);
        end if;
    end loop;
    wait;
  end process scoreboard;
  
end test_fixture;
