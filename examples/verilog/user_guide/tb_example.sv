// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_example;
   `TEST_SUITE begin

      `TEST_SUITE_SETUP begin
         $display("test suite setup");
      end

      `TEST_CASE_SETUP begin
         $display("test case setup");
      end

      `TEST_CASE("Test that pass") begin
         $display("pass");
      end

      `TEST_CASE("Test that fail") begin
         `CHECK_EQUAL(0, 1);
      end

      `TEST_CASE("Test that timeouts") begin
         #2ns;
      end

      `TEST_CASE_CLEANUP begin
         $display("test case cleanup");
      end

      `TEST_SUITE_CLEANUP begin
         $display("test suite cleanup");
      end
   end;

   `WATCHDOG(1ns);
endmodule
