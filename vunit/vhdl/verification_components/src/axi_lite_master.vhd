-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com


library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.bus_master_pkg.all;
use work.sync_pkg.all;
use work.axi_pkg.all;
use work.axi_slave_pkg.all;
use work.axi_slave_private_pkg.all;
use work.axi_lite_master_pkg.all;
context work.com_context;
context work.vunit_context;

entity axi_lite_master is
  generic(
    bus_handle : bus_master_t
  );
  port(
    aclk : in std_logic;

    arready : in std_logic;
    arvalid : out std_logic := '0';
    araddr : out std_logic_vector(address_length(bus_handle) - 1 downto 0) := (others => '0');

    rready : out std_logic := '0';
    rvalid : in std_logic;
    rdata : in std_logic_vector(data_length(bus_handle) - 1 downto 0);
    rresp : in axi_resp_t;

    awready : in std_logic;
    awvalid : out std_logic := '0';
    awaddr : out std_logic_vector(address_length(bus_handle) - 1 downto 0) := (others => '0');

    wready : in std_logic;
    wvalid : out std_logic := '0';
    wdata : out std_logic_vector(data_length(bus_handle) - 1 downto 0) := (others => '0');
    wstrb : out std_logic_vector(byte_enable_length(bus_handle) - 1 downto 0) := (others => '0');

    bvalid : in std_logic;
    bready : out std_logic := '0';
    bresp : in axi_resp_t := axi_resp_okay);
end entity;

architecture a of axi_lite_master is
  constant reply_queue, message_queue : queue_t := new_queue;
  signal idle : boolean := true;
begin
  main : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, bus_handle.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if is_read(msg_type) or is_write(msg_type) then
      push(message_queue, request_msg);
    elsif msg_type = wait_until_idle_msg then
      if not idle or not is_empty(message_queue) then
        wait until idle and is_empty(message_queue) and rising_edge(aclk);
      end if;
      handle_wait_until_idle(net, msg_type, request_msg);
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  -- Use separate process to always align to rising edge of clock
  bus_process : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable w_done, aw_done : boolean;
    variable expected_resp : axi_resp_t;
  begin
    wait until rising_edge(aclk) and not is_empty(message_queue);
    idle <= false;
    wait for 0 ps;

    request_msg := pop(message_queue);
    msg_type := message_type(request_msg);

    if is_read(msg_type) then
      araddr <= pop_std_ulogic_vector(request_msg);
      expected_resp := pop_std_ulogic_vector(request_msg) when is_axi_lite_msg(msg_type) else axi_resp_okay;
      push(reply_queue, request_msg);

      arvalid <= '1';
      wait until (arvalid and arready) = '1' and rising_edge(aclk);
      arvalid <= '0';

      rready <= '1';
      wait until (rvalid and rready) = '1' and rising_edge(aclk);
      rready <= '0';
      check_axi_resp(bus_handle, rresp, expected_resp, "rresp");

      if is_visible(bus_handle.p_logger, debug) then
        debug(bus_handle.p_logger,
              "Read 0x" & to_hstring(rdata) &
                " from address 0x" & to_hstring(araddr));
      end if;

    elsif is_write(msg_type) then
      awaddr <= pop_std_ulogic_vector(request_msg);
      wdata <= pop_std_ulogic_vector(request_msg);
      wstrb <= pop_std_ulogic_vector(request_msg);
      expected_resp := pop_std_ulogic_vector(request_msg) when is_axi_lite_msg(msg_type) else axi_resp_okay;
      delete(request_msg);

      wvalid <= '1';
      awvalid <= '1';

      w_done := false;
      aw_done := false;
      while not (w_done and aw_done) loop
        wait until ((awvalid and awready) = '1' or (wvalid and wready) = '1') and rising_edge(aclk);

        if (awvalid and awready) = '1' then
          awvalid <= '0';
          aw_done := true;
        end if;

        if (wvalid and wready) = '1' then
          wvalid <= '0';
          w_done := true;
        end if;
      end loop;

      bready <= '1';
      wait until (bvalid and bready) = '1' and rising_edge(aclk);
      bready <= '0';
      check_axi_resp(bus_handle, bresp, expected_resp, "bresp");

      if is_visible(bus_handle.p_logger, debug) then
        debug(bus_handle.p_logger,
              "Wrote 0x" & to_hstring(wdata) &
                " to address 0x" & to_hstring(awaddr));
      end if;
    end if;

    idle <= true;
  end process;

  -- Reply in separate process do not destroy alignment with the clock
  read_reply : process
    variable request_msg, reply_msg : msg_t;
  begin
    wait until (rvalid and rready) = '1' and rising_edge(aclk);
    request_msg := pop(reply_queue);
    reply_msg := new_msg;
    push_std_ulogic_vector(reply_msg, rdata);
    reply(net, request_msg, reply_msg);
    delete(request_msg);
  end process;

end architecture;
