-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;
use vunit_lib.vc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

use work.vc_pkg_with_template.all;

entity vc_with_template is
  generic(
    vc_h : vc_handle_t
  );
  port(
    a : in std_logic;
    b : in std_logic := '1';
    c, d : in std_logic_vector;
    e : in std_logic_vector := X"00";
    f : inout std_logic;
    g : inout std_logic := '0';
    h, i : inout std_logic := '0';
    j : out std_logic;
    k, l : out std_logic;
    m : out std_logic := '1'
  );
end entity;

architecture a of vc_with_template is
begin
  controller : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, get_actor(vc_h.p_std_cfg), msg);

    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);
    unexpected_msg_type(msg_type, vc_h.p_std_cfg);
  end process;
end architecture;
