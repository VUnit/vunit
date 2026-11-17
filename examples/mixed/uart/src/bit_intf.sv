// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

`include "vunit_defines.svh"

interface bit_intf (input clk);

   logic rx_tx;

   modport master (output rx_tx);
   modport slave  (input rx_tx);

   task automatic uart_send(input integer data, baud_rate);
      integer time_per_bit;
      time_per_bit = (10**9 / baud_rate);
      rx_tx = 1'b0;
      #(time_per_bit * 1ns);

      for (int i=0; i<8; i++) begin
         rx_tx = data[i];
         #(time_per_bit * 1ns);
      end

      rx_tx = 1'b1;
      #(time_per_bit * 1ns);
   endtask // uart_send

   task automatic check(output integer data, input int time_per_bit);
      data = 0;
      wait(rx_tx == 1'b0);
      #(time_per_bit/2 * 1ns);
      `CHECK_EQUAL(rx_tx, 1'b0, "Expected low rx_tx");
      #(time_per_bit * 1ns);
      for (int i=0; i<8; i++) begin
         data[i] = rx_tx;
         #(time_per_bit * 1ns);
      end
      `CHECK_EQUAL(rx_tx, 1'b1, "Expected high rx_tx");
      #(time_per_bit / 2 * 1ns);
   endtask


endinterface // bit_intf
