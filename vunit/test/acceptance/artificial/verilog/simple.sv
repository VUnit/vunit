// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

interface intf;
  logic a;
  logic b;
  modport in (input a, output b);
  modport out (input b, output a);
endinterface

module simple_sv();
   typedef struct packed {
      bit [10:0]  expo;
      bit         sign;
      bit [51:0]  mant;
   } FP;

   logic 	  clk;
   always_ff @(posedge clk) begin
   end

   always begin
      #1;
      $display("hello");
      #1;
   end
endmodule
