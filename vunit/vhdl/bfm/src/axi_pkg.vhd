-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

package axi_pkg is
  subtype axi_resp_t is std_logic_vector(1 downto 0);
  constant axi_resp_ok : axi_resp_t := "00";

  subtype axi_burst_type_t is std_logic_vector(1 downto 0);
  constant axi_burst_type_fixed : axi_burst_type_t := "00";
  constant axi_burst_type_incr : axi_burst_type_t := "01";
  constant axi_burst_type_wrap : axi_burst_type_t := "10";

  subtype axi4_len_t is std_logic_vector(7 downto 0);
  subtype axi4_size_t is std_logic_vector(2 downto 0);
end package;
