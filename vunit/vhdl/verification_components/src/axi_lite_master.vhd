-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


library ieee;
use ieee.std_logic_1164.all;

use work.axi_lite_master_pkg.all;
use work.axi_pkg.all;
use work.axi_slave_private_pkg.check_axi_resp;
use work.bus_master_pkg.address_length;
use work.bus_master_pkg.bus_master_t;
use work.bus_master_pkg.byte_enable_length;
use work.bus_master_pkg.data_length;
use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_types_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

entity axi_lite_master is
  generic (
    bus_handle : bus_master_t;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X'
  );
  port (
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
    bresp : in axi_resp_t := axi_resp_okay
  );
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
    procedure drive_ar_invalid is
    begin
      if drive_invalid then
        araddr <= (araddr'range => drive_invalid_val);
      end if;
    end procedure;

    procedure drive_aw_invalid is
    begin
      if drive_invalid then
        awaddr <= (awaddr'range => drive_invalid_val);
      end if;
    end procedure;

    procedure drive_w_invalid is
    begin
      if drive_invalid then
        wdata <= (wdata'range => drive_invalid_val);
        wstrb <= (wstrb'range => drive_invalid_val);
      end if;
    end procedure;

    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable expected_resp : axi_resp_t;
    variable w_done, aw_done : boolean;

    -- These variables are needed to keep the values for logging when transaction is fully done
    variable addr_this_transaction : std_logic_vector(awaddr'range) := (others => '0');
    variable wdata_this_transaction : std_logic_vector(wdata'range) := (others => '0');
  begin
    -- Initialization
    drive_ar_invalid;
    drive_aw_invalid;
    drive_w_invalid;

    loop
      wait until rising_edge(aclk) and not is_empty(message_queue);
      idle <= false;
      wait for 0 ps;

      request_msg := pop(message_queue);
      msg_type := message_type(request_msg);

      if is_read(msg_type) then
        addr_this_transaction := pop_std_ulogic_vector(request_msg);
        expected_resp := pop_std_ulogic_vector(request_msg) when is_axi_lite_msg(msg_type) else axi_resp_okay;
        push(reply_queue, request_msg);

        arvalid <= '1';
        araddr <= addr_this_transaction;
        wait until (arvalid and arready) = '1' and rising_edge(aclk);
        arvalid <= '0';
        drive_ar_invalid;

        rready <= '1';
        wait until (rvalid and rready) = '1' and rising_edge(aclk);
        rready <= '0';
        check_axi_resp(bus_handle, rresp, expected_resp, "rresp");

        if is_visible(bus_handle.p_logger, debug) then
          debug(bus_handle.p_logger,
                "Read 0x" & to_hstring(rdata) &
                  " from address 0x" & to_hstring(addr_this_transaction));
        end if;

      elsif is_write(msg_type) then
        addr_this_transaction := pop_std_ulogic_vector(request_msg);
        wdata_this_transaction := pop_std_ulogic_vector(request_msg);
        wstrb <= pop_std_ulogic_vector(request_msg);
        expected_resp := pop_std_ulogic_vector(request_msg) when is_axi_lite_msg(msg_type) else axi_resp_okay;
        delete(request_msg);

        awaddr <= addr_this_transaction;
        wdata <= wdata_this_transaction;

        wvalid <= '1';
        awvalid <= '1';

        w_done := false;
        aw_done := false;
        while not (w_done and aw_done) loop
          wait until ((awvalid and awready) = '1' or (wvalid and wready) = '1') and rising_edge(aclk);

          if (awvalid and awready) = '1' then
            awvalid <= '0';
            drive_aw_invalid;

            aw_done := true;
          end if;

          if (wvalid and wready) = '1' then
            wvalid <= '0';
            drive_w_invalid;

            w_done := true;
          end if;
        end loop;

        bready <= '1';
        wait until (bvalid and bready) = '1' and rising_edge(aclk);
        bready <= '0';
        check_axi_resp(bus_handle, bresp, expected_resp, "bresp");

        if is_visible(bus_handle.p_logger, debug) then
          debug(bus_handle.p_logger,
                "Wrote 0x" & to_hstring(wdata_this_transaction) &
                  " to address 0x" & to_hstring(addr_this_transaction));
        end if;
      end if;

      idle <= true;
    end loop;
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
