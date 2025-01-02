-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.avalon_stream_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

entity tb_avalon_stream_pkg is
  generic (runner_cfg : string);
end entity;

architecture a of tb_avalon_stream_pkg is
  signal clk   : std_logic := '0';
begin

  main : process
    variable msg                           : msg_t;
    variable msg_type                      : msg_type_t;
    variable avalon_stream_transaction     : avalon_stream_transaction_t(data(7 downto 0));
    variable avalon_stream_transaction_tmp : avalon_stream_transaction_t(data(7 downto 0));
  begin
    test_runner_setup(runner, runner_cfg);
    set_format(display_handler, verbose, true);

    wait until rising_edge(clk);
    if run("test single transaction push and pop") then
      avalon_stream_transaction.data := x"ab";
      msg := new_avalon_stream_transaction_msg(avalon_stream_transaction);
      msg_type := message_type(msg);
      handle_avalon_stream_transaction(msg_type, msg, avalon_stream_transaction_tmp);
      check_equal(avalon_stream_transaction_tmp.data, avalon_stream_transaction.data, "pop stream transaction data");

    elsif run("test double transaction push and pop") then
      avalon_stream_transaction.data := x"a5";
      msg := new_avalon_stream_transaction_msg(avalon_stream_transaction);
      msg_type := message_type(msg);
      handle_avalon_stream_transaction(msg_type, msg, avalon_stream_transaction_tmp);
      check_equal(avalon_stream_transaction_tmp.data, avalon_stream_transaction.data, "pop stream transaction data");

      avalon_stream_transaction.data := x"9e";
      msg := new_avalon_stream_transaction_msg(avalon_stream_transaction);
      msg_type := message_type(msg);
      handle_avalon_stream_transaction(msg_type, msg, avalon_stream_transaction_tmp);
      check_equal(avalon_stream_transaction_tmp.data, avalon_stream_transaction.data, "pop stream transaction data");

    elsif run("test transaction push delay pop") then
      avalon_stream_transaction.data := x"f1";
      msg := new_avalon_stream_transaction_msg(avalon_stream_transaction);
      msg_type := message_type(msg);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      handle_avalon_stream_transaction(msg_type, msg, avalon_stream_transaction_tmp);
      check_equal(avalon_stream_transaction_tmp.data, avalon_stream_transaction.data, "pop stream transaction data");

    elsif run("test transaction sop and eop") then
      for i in 0 to 7 loop
        avalon_stream_transaction.data := std_logic_vector(to_unsigned(i, 8));
        avalon_stream_transaction.sop  := (i = 0);
        avalon_stream_transaction.eop  := (i = 7);
        msg := new_avalon_stream_transaction_msg(avalon_stream_transaction);
        msg_type := message_type(msg);
        handle_avalon_stream_transaction(msg_type, msg, avalon_stream_transaction_tmp);
        check_equal(avalon_stream_transaction_tmp.data, std_logic_vector(to_unsigned(i, 8)), "pop stream data"&natural'image(i));
        check_equal(avalon_stream_transaction_tmp.sop, i = 0, "pop stream sop");
        check_equal(avalon_stream_transaction_tmp.eop, i = 7, "pop stream eop");
      end loop;

    end if;
    wait until rising_edge(clk);
    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 10 ms);

  clk <= not clk after 5 ns;
end architecture;
