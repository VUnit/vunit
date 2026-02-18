// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

module tb_uart_mix;

   localparam integer baud_rate = 115200; // bits / s
   localparam integer clk_period = 20; // ns
   localparam integer cycles_per_bit = 50 * 10**6 / baud_rate;
   localparam time_per_bit = (10**9 / baud_rate);
   localparam time_per_half_bit = time_per_bit/2;
   logic clk = 1'b0;

   axis_intf #(.DW(8)) m_axis (clk);
   axis_intf s_axis (clk);

   bit_intf  bit_if(clk);

   logic overflow;

   int   uart_data;

   int num_overflows = 0;

   `TEST_SUITE begin
      `TEST_CASE("test_tvalid_low_at_start") begin
         fork : tvalid_low_check
            begin
               wait (s_axis.tvalid == 1'b1);
               $error("tvalid should not be high unless data received");
               disable tvalid_low_check;
            end
            begin
               #100ns;
               disable tvalid_low_check;
            end
         join
      end

      `TEST_CASE("test_send_receive_one_byte") begin
         fork
            m_axis.send(8'h77);
            s_axis.check(8'h77);
            bit_if.check(uart_data, time_per_bit);
         join
         `CHECK_EQUAL(num_overflows, 0)
      end

      `TEST_CASE("test_two_bytes_cause_overflow") begin
         fork
            m_axis.send(8'h77);
            bit_if.check(uart_data, time_per_bit);
         join
         `CHECK_EQUAL(uart_data, 8'h77)
         @(posedge clk iff s_axis.tvalid == 1'b1);
         `CHECK_EQUAL(num_overflows, 0)
         fork
            m_axis.send(8'h77);
            bit_if.check(uart_data, time_per_bit);
         join
         `CHECK_EQUAL(uart_data, 8'h77)
         `CHECK_EQUAL(num_overflows, 1);
      end
   end

   `WATCHDOG(10ms);

   initial begin
      m_axis.tvalid = 0;
      s_axis.tready = 0;
   end

   always @(posedge clk iff overflow == 1'b1) begin
      num_overflows <= num_overflows + 1;
   end

   always begin
      #(clk_period/2 * 1ns);
      clk <= !clk;
   end

   uart_tx #(.cycles_per_bit(cycles_per_bit))
   dut_tx
     (.clk      (clk),
      .tx       (bit_if.rx_tx),
      .tready   (m_axis.tready),
      .tvalid   (m_axis.tvalid),
      .tdata    (m_axis.tdata));

   uart_rx #(.cycles_per_bit(cycles_per_bit))
   dut_rx
     (.clk      (clk),
      .rx       (bit_if.rx_tx),
      .overflow (overflow),
      .tready   (s_axis.tready),
      .tvalid   (s_axis.tvalid),
      .tdata    (s_axis.tdata));

endmodule // tb_uart_mix
