// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

// You do not need to worry about adding vunit_defines.svh to your
// include path, VUnit will automatically do that for you if VUnit is
// correctly installed (and your python run-script is correct).
`include "vunit_defines.svh"

module tb_example;
   `TEST_SUITE begin
      // Note: Do not place any code here (unless you are debugging
      // VUnit internals).

      `TEST_SUITE_SETUP begin
         // Here you will typically place things that are common to
         // all tests, such as asserting the reset signal and starting
         // the clock(s).
         $display("Running test suite setup code");
      end

      `TEST_CASE_SETUP begin
         // By default VUnit will run each test separately. However,
         // advanced users may want to run tests consecutively rather
         // than in separate instances of the HDL-simulator. In that
         // case the code placed in a TEST_CASE_SETUP block should
         // restore the unit under test to the state expected by the
         // test cases below. In many cases this block would only
         // assert/deassert the reset signal for a couple of
         // clock-cycles.
         //
         // When trying out VUnit for the first time this section
         // should probably be left empty.
         $display("Running test case setup code");
      end

      `TEST_CASE("Test that a successful test case passes") begin
         $display("This test case is expected to pass");
         `CHECK_EQUAL(1, 1);
      end

      `TEST_CASE("Test that a failing test case actually fails") begin
         $display("This test case is expected to fail");
         `CHECK_EQUAL(0, 1, "You may also optionally add a diagnostic message to CHECK_EQUAL");
         // Note: A test case will also be marked as failing if the
         // simulator stops for other reasons before the end of the
         // TEST_SUITE block is reached. This means that you don't
         // need to use CHECK_EQUAL if the testbench you want to
         // convert to VUnit already contains code that for example
         // calls $stop if an error-condition is detected.
      end

      `TEST_CASE("Test that a test case that takes too long time fails with a timeout") begin
         $display("This test is expected to timeout because of the watch dog below.");
         #2ns; //
      end

      `TEST_CASE_CLEANUP begin
         // This section will run after the end of a test case. In
         // many cases this section will not be needed.
         $display("Cleaning up after a test case");
      end

      `TEST_SUITE_CLEANUP begin
         // This section will run last before the TEST_SUITE block
         // exits. In many cases this section will not be needed.
         $display("Cleaning up after running the complete test suite");
      end
   end;

   // The watchdog macro is optional, but recommended. If present, it
   // must not be placed inside any initial or always-block.
   `WATCHDOG(1ns);
endmodule
