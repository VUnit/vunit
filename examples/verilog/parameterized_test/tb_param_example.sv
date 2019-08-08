// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

// You do not need to worry about adding vunit_defines.svh to your
// include path, VUnit will automatically do that for you if VUnit is
// correctly installed (and your python run-script is correct).
`include "vunit_defines.svh"

module tb_param_example;
    parameter DESCRIPTION = "";
    parameter NUMBER = 0;

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

      `TEST_CASE("Test that a parameterized DESCRIPTION") begin
         $display("------------------------------");
         $display("%s",DESCRIPTION);
         $display("------------------------------");
      end

      `TEST_CASE("Test that a parameterized NUMBER") begin
         $display("------------------------------");
         $display("Set NUMBER is %0d",NUMBER);
         $display("------------------------------");
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
