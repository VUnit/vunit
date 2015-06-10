// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_example;
   `TEST_SUITE begin

      `TEST_SUITE_SETUP begin
         $info("test suite setup");
      end

      `TEST_CASE_SETUP begin
         $info("test case setup");
      end

      `TEST_CASE("Test that pass") begin
         $info("pass");
      end

      `TEST_CASE("Test that fail") begin
         `CHECK_EQUAL(0, 1);
      end

      `TEST_CASE("Test that timeouts") begin
         #2ns;
      end

      `TEST_CASE_TEARDOWN begin
         $info("test case teardown");
      end

      `TEST_SUITE_TEARDOWN begin
         $info("test suite teardown");
      end
   end;

   `WATCHDOG(1ns);
endmodule
