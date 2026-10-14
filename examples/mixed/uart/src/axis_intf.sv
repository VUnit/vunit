// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

interface axis_intf #(parameter int DW=8) (input logic clk);

   logic tready;
   logic tvalid;
   logic [DW-1:0] tdata;

   modport master (input tready, output tvalid, tdata);
   modport slave  (output tready, input tvalid, tdata);

   task automatic send(int word);
      tvalid <= 1'b1;
      tdata <= word;
      //words.push_back(word);
      @(posedge clk iff tvalid == 1'b1 && tready == 1'b1);
      $info($sformatf("AXIs: Sent word x%0h", word));
      tvalid <= 1'b0;
   endtask // send

   task automatic check (int word);
      tready <= 1'b1;
      do
        @(posedge clk);
      while (tvalid !=1);
      `CHECK_EQUAL(tdata, word);
      tready <= 1'b0;
      @(posedge clk);
      `CHECK_EQUAL(tvalid, 1'b0);
   endtask // receive

endinterface // axis_intf

