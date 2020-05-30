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

use work.vc_not_supporting_custom_logger_pkg.all;

entity vc_not_supporting_custom_logger is
  generic(
    vc_h : vc_not_supporting_custom_logger_handle_t
  );
end entity;

architecture a of vc_not_supporting_custom_logger is
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

