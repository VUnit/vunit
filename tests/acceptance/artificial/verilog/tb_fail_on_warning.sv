// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

// vunit: fail_on_warning

`include "vunit_defines.svh"

module tb_fail_on_warning;
   `TEST_SUITE begin
      `TEST_CASE("fail") begin
         $warning("A warning");
      end
   end;
endmodule
