-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sobel_x is
  generic (
    data_width : natural);
  port (
    signal clk : in std_logic;
    signal input_tvalid : in std_logic;
    signal input_tlast : in std_logic;
    signal input_tdata : in unsigned(data_width-1 downto 0);

    signal output_tvalid : out std_logic := '0';
    signal output_tlast : out std_logic;
    signal output_tdata : out signed(data_width downto 0));
end entity;

architecture a of sobel_x is
begin

  main : process
    variable input_tdata_p1, input_tdata_p2 : unsigned(input_tdata'range) := (others => '0');
    variable input_tvalid_p1 : std_logic := '0';
    variable input_tlast_p1 : std_logic := '0';
    variable first : boolean := true;
    variable pos, neg : unsigned(input_tdata'range) := (others => '0');
  begin
    wait until rising_edge(clk);
    output_tvalid <= input_tvalid_p1;
    output_tlast <= input_tlast_p1;

    if first then
      neg := input_tdata_p1;
    else
      neg := input_tdata_p2;
    end if;

    if input_tlast_p1 = '1' then
      pos := input_tdata_p1;
    else
      pos := input_tdata;
    end if;

    output_tdata <= signed(resize(pos, output_tdata'length) -
                           resize(neg, output_tdata'length));

    if input_tvalid_p1 = '1' then
      if input_tlast_p1 ='1' then
        first := true;
      else
        first := false;
      end if;
    end if;

    input_tlast_p1 := input_tlast;
    input_tvalid_p1 := input_tvalid;

    input_tdata_p2 := input_tdata_p1;
    input_tdata_p1 := input_tdata;
  end process;
end architecture;
