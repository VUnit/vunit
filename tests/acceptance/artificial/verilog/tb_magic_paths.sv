// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


`include "vunit_defines.svh"

module tb_magic_paths;
   parameter string tb_path = "";
   parameter string output_path = "";

   function void check_equal(string got, string expected);
      assert (got == expected) else $error("Mismatch got %s expected %s", got, expected);
   endfunction;

   function void check_has_suffix(string value, string suffix);
      check_equal(value.substr(value.len()-suffix.len(), value.len()-1), suffix);
   endfunction;

   `TEST_SUITE begin
      `TEST_CASE("Test magic paths are correct") begin
         check_has_suffix(tb_path, "acceptance/artificial/verilog/");
      end
   end;

   `WATCHDOG(1ns);
endmodule
