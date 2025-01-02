// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

module uart_rx(clk, rx, overflow, tready, tvalid, tdata);
   parameter integer cycles_per_bit = 434;

   input logic       clk;

   // Serial input bit
   input logic       rx;

   output logic      overflow = 1'b0;

   // AXI stream for input bytes
   input logic       tready;
   output logic      tvalid = 1'b0;
   output logic [7:0] tdata;

   typedef enum       {idle, receiving, done} state_t;
   state_t state = idle;

   logic [7:0]        data;
   logic [$bits(cycles_per_bit)-1:0] cycles = 0;
   logic [$bits($size(data))-1:0]    index;

   always @(posedge clk) begin
      overflow <= 1'b0;

      case (state)
        idle : begin
           if (rx == 1'b0) begin
              if (cycles == cycles_per_bit/2 - 1) begin
                 state = receiving;
                 cycles <= 0;
                 index <= 0;
              end else begin
                 cycles <= cycles + 1;
              end
           end else begin
              cycles <= 0;
           end
        end

        receiving : begin
           if (cycles == cycles_per_bit - 1) begin
              data <= {rx, data[$size(data)-1:1]};
              cycles <= 0;

              if (index == $size(data) - 1) begin
                 state <= done;
              end else begin
                 index <= index + 1;
              end
           end else begin
              cycles <= cycles + 1;
           end
        end

        done : begin
           overflow <= tvalid && !tready;
           tvalid <= 1'b1;
           tdata <= data;
           state <= idle;
        end
      endcase

      if (tvalid == 1'b1 && tready == 1'b1) begin
         tvalid <= 1'b0;
      end
   end
endmodule
