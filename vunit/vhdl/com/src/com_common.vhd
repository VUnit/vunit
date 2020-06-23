-- Com common package provides functionality shared among the other packages
-- The package is private to com.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com
library ieee;
use ieee.std_logic_1164.all;

use work.com_messenger_pkg.all;
use work.com_types_pkg.all;

package com_common_pkg is
  shared variable messenger :       messenger_t;

  procedure notify (signal net : inout network_t);

  impure function no_error_status (status : com_status_t; old_api : boolean := false) return boolean;
end package com_common_pkg;

package body com_common_pkg is
  procedure notify (signal net : inout network_t) is
  begin
    if net /= network_event then
      net <= network_event;
      wait until net = network_event;
      net <= idle_network;
    end if;
  end procedure notify;

  impure function no_error_status (status : com_status_t; old_api : boolean := false) return boolean is
  begin
    return (status = ok) or ((status = timeout) and messenger.timeout_is_allowed and old_api);
  end;

end package body com_common_pkg;
