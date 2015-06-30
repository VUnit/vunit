-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity card_shuffler is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    input_card   : in  std_logic_vector(5 downto 0);
    input_valid  : in  std_logic;
    output_card  : out std_logic_vector(5 downto 0);
    output_valid : out std_logic);
end entity card_shuffler;

architecture behavioral of card_shuffler is
  signal shuffled_deck     : integer_vector(1 to 52);
  signal new_deck_recieved : boolean := false;
begin
  receive_deck : process is
    variable n_cards : natural := 0;
    variable deck    : integer_vector(1 to 52);
    function shuffle (
      constant deck : integer_vector(1 to 52))
      return integer_vector is
      variable ret_val : integer_vector(1 to 52);
    begin
      ret_val(1 to 26)  := deck(27 to 52);
      ret_val(27 to 52) := deck(1 to 26);
      return ret_val;
    end function shuffle;
  begin
    wait until rising_edge(clk);
    if rst = '1' then
      n_cards := 0;
    elsif input_valid = '1' then
      n_cards       := n_cards + 1;
      deck(n_cards) := to_integer(unsigned(input_card));
    end if;

    if n_cards = 52 then
      n_cards           := 0;
      shuffled_deck     <= shuffle(deck);
      new_deck_recieved <= true;
      wait for 0 ns;
      new_deck_recieved <= false;
    end if;
  end process receive_deck;

  output_driver : process is
  begin
    output_valid <= '0';
    wait until new_deck_recieved;
    for i in 1 to 52 loop
      wait until rising_edge(clk);
      output_card  <= std_logic_vector(to_unsigned(shuffled_deck(i), 6));
      output_valid <= '1';
    end loop;
    wait until rising_edge(clk);
  end process output_driver;

end architecture behavioral;
