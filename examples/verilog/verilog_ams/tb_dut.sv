// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_dut;
   var real vout;

   `TEST_SUITE begin
      `TEST_CASE("Test that pass") begin
         @(vout);
         `CHECK_EQUAL(vout, 3.0);
      end

      `TEST_CASE("Test that fail") begin
         @(vout);
         `CHECK_EQUAL(vout, 2.0);
      end
   end;

   dut dut_inst(.vout(vout));

   `WATCHDOG(1ms);
endmodule
