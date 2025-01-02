// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

// vunit: run_all_in_same_sim

`include "vunit_defines.svh"

module tb_same_sim_some_fail;

   `TEST_SUITE begin

      `TEST_CASE("Test 1") begin
         $info("Test 1");
      end

      `TEST_CASE("Test 2") begin
         $info("Test 2");
         $error("");
      end

      `TEST_CASE("Test 3") begin
         $info("Test 3");
      end
   end;

   `WATCHDOG(1ns);
endmodule
