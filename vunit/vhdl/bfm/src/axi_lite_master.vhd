-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com


library ieee;
use ieee.std_logic_1164.all;

use work.axi_pkg.all;
use work.queue_pkg.all;
use work.bus_pkg.all;
use work.axi_private_pkg.all;
use work.msg_types_pkg.all;
context work.com_context;

entity axi_lite_master is
  generic (
    bus_handle : bus_t
    );
  port (
    aclk : in std_logic;

    arready : in std_logic;
    arvalid : out std_logic := '0';
    araddr : out std_logic_vector(address_length(bus_handle)-1 downto 0) := (others => '0');

    rready : out std_logic := '0';
    rvalid : in std_logic;
    rdata : in std_logic_vector(data_length(bus_handle)-1 downto 0);
    rresp : in axi_resp_t;

    awready : in std_logic;
    awvalid : out std_logic := '0';
    awaddr : out std_logic_vector(address_length(bus_handle)-1 downto 0) := (others => '0');

    wready : in std_logic;
    wvalid : out std_logic := '0';
    wdata : out std_logic_vector(data_length(bus_handle)-1 downto 0) := (others => '0');
    wstrb : out std_logic_vector(byte_enable_length(bus_handle)-1 downto 0) := (others => '0');

    bvalid : in std_logic;
    bready : out std_logic;
    bresp : in axi_resp_t := axi_resp_okay);
end entity;

architecture a of axi_lite_master is
begin
  main : process
    variable request_msg, reply_msg : msg_t;
    variable msg_type : msg_type_t;
    variable w_done, aw_done : boolean;
  begin
    loop
      receive(event, bus_handle.p_actor, request_msg);
      msg_type := pop_msg_type(request_msg);

      if msg_type = bus_read_msg then
        araddr <= pop_std_ulogic_vector(request_msg);
        arvalid <= '1';
        wait until (arvalid and arready) = '1' and rising_edge(aclk);
        arvalid <= '0';

        rready <= '1';
        wait until (rvalid and rready) = '1' and rising_edge(aclk);
        rready <= '0';
        check_axi_resp(bus_handle, rresp, axi_resp_okay, "rresp");

        reply_msg := create;
        push_std_ulogic_vector(reply_msg, rdata);
        reply(event, request_msg, reply_msg);
        delete(request_msg);

      elsif msg_type = bus_write_msg then
        awaddr <= pop_std_ulogic_vector(request_msg);
        wdata <= pop_std_ulogic_vector(request_msg);
        wstrb <= pop_std_ulogic_vector(request_msg);

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
        check_axi_resp(bus_handle, bresp, axi_resp_okay, "bresp");
      else
        unexpected_msg_type(msg_type);
      end if;
    end loop;
  end process;
end architecture;
