-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

entity card_shuffler is
  port (
    clk          : in  std_logic;
    rst        : in  std_logic;
    input_card   : in  std_logic_vector(5 downto 0);
    input_valid  : in  std_logic;
    output_card  : out std_logic_vector(5 downto 0);
    output_valid : out std_logic);
end entity card_shuffler;

architecture behavioral of card_shuffler is
begin
  output_card <= input_card;
  output_valid <= input_valid;
end architecture behavioral;
