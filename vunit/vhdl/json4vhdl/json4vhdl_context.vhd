-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

context json4vhdl_context is
  library vunit_lib;
  use vunit_lib.json.T_JSON;
  use vunit_lib.json.jsonLoad;
  use vunit_lib.json.jsonGetString;
  use vunit_lib.json.jsonGetBoolean;
  use vunit_lib.json4vhdl_decode.decode_array;
end context;
