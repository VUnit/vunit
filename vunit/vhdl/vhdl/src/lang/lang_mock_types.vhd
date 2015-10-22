-- This package provides types used by the lang mocks.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package lang_mock_types_pkg is
  type report_call_args_t is record
    valid : boolean;
    msg     : string(1 to 1024);
    msg_length : natural;
    level : severity_level;
  end record;

  type write_call_args_t is record
    valid : boolean;
    msg     : string(1 to 1024);
    msg_length : natural;
  end record;
end package lang_mock_types_pkg;
