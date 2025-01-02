// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_uart_tx;
   localparam integer baud_rate = 115200; // bits / s
   localparam integer clk_period = 20; // ns
   localparam integer cycles_per_bit = 50 * 10**6 / baud_rate;
   localparam time_per_bit = (10**9 / baud_rate);
   localparam time_per_half_bit = time_per_bit/2;
   logic clk = 1'b0;

   // Serial output bit
   logic tx;

   // AXI stream for input bytes
   logic tready;
   logic  tvalid = 1'b0;
   logic  [7:0]tdata;

   int     words[$];
   int     num_recv;

   task automatic send();
      int word = $urandom_range(255);
      tvalid <= 1'b1;
      tdata <= word;
      words.push_back(word);
      @(posedge clk iff tvalid == 1'b1 && tready == 1'b1);
      $info("AXI: Sent word ", word);
      tvalid <= 1'b0;
   endtask

   task automatic check_all_was_received();
      wait (words.size() == num_recv);
   endtask

   `TEST_SUITE begin
      `TEST_CASE("test_send_one_byte") begin
         send();
         check_all_was_received();
      end
      `TEST_CASE("test_send_many_bytes") begin
         for (int i=0; i<7; i++) begin
            send();
         end
         check_all_was_received();
      end
   end

   `WATCHDOG(10ms);

   always begin
      #(clk_period/2 * 1ns);
      clk <= !clk;
   end

   task automatic uart_recv(output integer data);
      data = 0;
      wait(tx == 1'b0);
      #(time_per_half_bit * 1ns);
      `CHECK_EQUAL(tx, 1'b0, "Expected low tx");
      #(time_per_bit * 1ns);
      for (int i=0; i<8; i++) begin
         data[i] = tx;
         #(time_per_bit * 1ns);
      end
      `CHECK_EQUAL(tx, 1'b1, "Expected high tx");
      #(time_per_half_bit * 1ns);
   endtask

   always begin
      integer data;
      uart_recv(data);
      $info("WIRE: Received data ", data);
      `CHECK_EQUAL(data, words[num_recv]);
      num_recv = num_recv + 1;
   end

   uart_tx #(.cycles_per_bit(cycles_per_bit)) dut(.*);


endmodule
