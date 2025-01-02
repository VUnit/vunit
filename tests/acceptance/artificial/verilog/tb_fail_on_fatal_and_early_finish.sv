// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


`include "vunit_defines.svh"

module tb_fail_on_fatal_and_early_finish;
   `TEST_SUITE begin
      `TEST_CASE("fatal0") begin
         $fatal(0, "fatal0");
      end

      `TEST_CASE("fatal1") begin
         $fatal(1, "fatal1");
      end

      `TEST_CASE("finish0") begin
         $finish(0);
      end

      `TEST_CASE("finish1") begin
         $finish(1);
      end
   end;
endmodule
