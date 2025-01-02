// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

module uart_tx(clk, tx, tready, tvalid, tdata);
   parameter integer cycles_per_bit = 434;

   input logic clk;

   // Serial output bit
   output logic tx = 1'b1;

   // AXI stream for input bytes
   output logic tready = 1'b1;
   input logic  tvalid;
   input logic [7:0] tdata;

   typedef enum  {idle, sending} state_t;
   state_t state = idle;

   logic [9:0] data;
   logic [$bits(cycles_per_bit)-1:0] cycles;
   logic [$bits($size(data))-1:0] index;


   always @(posedge clk)
     begin
        case (state)
          idle : begin
             tx <= 1'b1;
             if (tvalid == 1'b1 && tready == 1'b1) begin
                state <= sending;
                tready <= 1'b0;
                cycles <= 0;
                index <= 0;
                data <= {1'b1, tdata, 1'b0};
             end
          end

          sending : begin
             tx <= data[0];

             if (cycles == cycles_per_bit - 1) begin
                if (index == $size(data)-1) begin
                   state <= idle;
                   tready <= 1'b1;
                end else begin
                   index <= index + 1;
                end
                data <= {1'b0, data[$size(data)-1:1]};
                cycles <= 0;
             end else begin
                cycles <= cycles + 1;
             end
          end
        endcase
     end
endmodule
