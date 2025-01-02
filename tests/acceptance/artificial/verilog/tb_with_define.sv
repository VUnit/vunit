// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


`include "vunit_defines.svh"

module tb_with_define;
   `TEST_SUITE begin

      `TEST_CASE("test 1") begin
`ifndef DEFINE_FROM_RUN_PY
         `CHECK_EQUAL(0, 1);
`endif
      end
   end;

   `WATCHDOG(1ns);
endmodule
