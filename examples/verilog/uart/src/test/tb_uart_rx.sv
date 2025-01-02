// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_uart_rx;
   localparam integer baud_rate = 115200; // bits / s
   localparam integer clk_period = 20; // ns
   localparam integer cycles_per_bit = 50 * 10**6 / baud_rate;
   localparam time_per_bit = (10**9 / baud_rate);
   localparam time_per_half_bit = time_per_bit/2;
   logic clk = 1'b0;

   // Serial input bit
   logic rx = 1'b0;

   // AXI stream for input bytes
   logic overflow;
   logic tready = 1'b0;
   logic  tvalid;
   logic  [7:0]tdata;
   integer     num_overflows = 0;

   `TEST_SUITE begin
      `TEST_CASE("test_tvalid_low_at_start") begin
         fork : tvalid_low_check
            begin
               wait (tvalid == 1'b1);
               $error("tvalid should not be high unless data received");
               disable tvalid_low_check;
            end
            begin
               #100ns;
               disable tvalid_low_check;
            end
         join
      end

      `TEST_CASE("test_receives_one_byte") begin
         uart_send(77, rx, baud_rate);
         tready <= 1'b1;
         @(posedge clk iff tready == 1'b1 && tvalid == 1'b1);
         `CHECK_EQUAL(tdata, 77);
         tready <= 1'b0;
         `CHECK_EQUAL(num_overflows, 0);
         @(posedge clk);
         `CHECK_EQUAL(tvalid, 1'b0);
      end

      `TEST_CASE("test_two_bytes_cause_overflow") begin
         uart_send(77, rx, baud_rate);
         @(posedge clk iff tvalid == 1'b1);
         `CHECK_EQUAL(num_overflows, 0);
         uart_send(77, rx, baud_rate);
         `CHECK_EQUAL(num_overflows, 1);
      end
   end

   `WATCHDOG(10ms);

   task automatic uart_send(input integer data, ref logic rx, input integer baud_rate);
      integer time_per_bit;
      time_per_bit = (10**9 / baud_rate);
      rx = 1'b0;
      #(time_per_bit * 1ns);

      for (int i=0; i<8; i++) begin
         rx = data[i];
         #(time_per_bit * 1ns);
      end

      rx = 1'b1;
      #(time_per_bit * 1ns);
   endtask

   always begin
      #(clk_period/2 * 1ns);
      clk <= !clk;
   end

   always @(posedge clk iff overflow == 1'b1) begin
      num_overflows <= num_overflows + 1;
   end

   uart_rx #(.cycles_per_bit(cycles_per_bit)) dut(.*);

endmodule
