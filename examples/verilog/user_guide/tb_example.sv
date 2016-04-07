// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

// You do not need to worry about adding vunit_defines.svh to your
// include path, VUnit will automatically do that for you if your
// python run-script is correct.
`include "vunit_defines.svh"

module tb_example;
   `TEST_SUITE begin
      // Note: Do not place any code here (unless you are debuggnig
      // VUnit internals).
      
      `TEST_SUITE_SETUP begin
         // Here you will typically place things that are common to
         // all tests, such as asserting the reset signal, starting
         // the clock.
         $display("test suite setup");
      end

      `TEST_CASE_SETUP begin
         $display("test case setup");
      end

      `TEST_CASE("Test that pass") begin
         $display("this test is expected to pass");
         `CHECK_EQUAL(1, 1);
      end

      `TEST_CASE("Test that fail") begin
         $display("this test is expected to fail");
         `CHECK_EQUAL(0, 1, "You may also optionally add a diagnostic message to CHECK_EQUAL");
      end

      `TEST_CASE("Test that timeouts") begin
         $display("this test is expected to timeout");
         #2ns;
      end

      `TEST_CASE_CLEANUP begin
         $display("test case cleanup");
      end

      `TEST_SUITE_CLEANUP begin
         $display("test suite cleanup");
      end
   end;

   // The watchdog macro is optional, but recommended. If you use it
   // it must not be placed inside any initial or always-block
   `WATCHDOG(1ns);
endmodule
