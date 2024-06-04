-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com
-- Author David Martin david.martin@phios.group


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.axi_master_pkg.all;
use work.axi_pkg.all;
use work.axi_slave_private_pkg.check_axi_resp;
use work.axi_slave_private_pkg.check_axi_id;
use work.bus_master_pkg.all;
use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_types_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

entity axi_master is
  generic (
    bus_handle : bus_master_t;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X';
    write_high_probability : real range 0.0 to 1.0 := 1.0;
    read_high_probability : real range 0.0 to 1.0 := 1.0
  );
  port (
    aclk : in std_logic;

    arvalid : out std_logic := '0';
    arready : in std_logic;
    arid : out std_logic_vector;
    araddr : out std_logic_vector(address_length(bus_handle) - 1 downto 0) := (others => '0');
    arlen : out std_logic_vector;
    arsize : out std_logic_vector;
    arburst : out axi_burst_type_t;

    rvalid : in std_logic;
    rready : out std_logic := '0';
    rid : in std_logic_vector;
    rdata : in std_logic_vector(data_length(bus_handle) - 1 downto 0);
    rresp : in axi_resp_t;
    rlast : in std_logic;

    awvalid : out std_logic := '0';
    awready : in std_logic := '0';
    awid : out std_logic_vector;
    awaddr : out std_logic_vector(address_length(bus_handle) - 1 downto 0) := (others => '0');
    awlen : out std_logic_vector;
    awsize : out std_logic_vector;
    awburst : out axi_burst_type_t;

    wvalid : out std_logic;
    wready : in std_logic := '0';
    wdata : out std_logic_vector(data_length(bus_handle) - 1 downto 0) := (others => '0');
    wstrb : out std_logic_vector(byte_enable_length(bus_handle) - 1 downto 0) := (others => '0');
    wlast : out std_logic;

    bvalid : in std_logic;
    bready : out std_logic := '0';
    bid : in std_logic_vector;
    bresp : in axi_resp_t := axi_resp_okay
  );
end entity;

architecture a of axi_master is
  constant read_reply_queue, write_reply_queue, message_queue : queue_t := new_queue;
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
        arlen <= (arlen'range => drive_invalid_val);
        arsize <= (arsize'range => drive_invalid_val);
        arburst <= (arburst'range => drive_invalid_val);
        arid <= (arid'range => drive_invalid_val);
      end if;
    end procedure;

    procedure drive_aw_invalid is
    begin
      if drive_invalid then
        awaddr <= (awaddr'range => drive_invalid_val);
        awlen <= (awlen'range => drive_invalid_val);
        awsize <= (awsize'range => drive_invalid_val);
        awburst <= (awburst'range => drive_invalid_val);
        awid <= (arid'range => drive_invalid_val);
      end if;
    end procedure;

    procedure drive_w_invalid is
    begin
      if drive_invalid then
        wlast <= drive_invalid_val;
        wdata <= (wdata'range => drive_invalid_val);
        wstrb <= (wstrb'range => drive_invalid_val);
      end if;
    end procedure;

    function get_full_size return std_logic_vector is
      begin
        return std_logic_vector(to_unsigned(integer(ceil(log2(real(rdata'length/8)))), arsize'length));
    end function;

    variable rnd : RandomPType;
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable w_done, aw_done : boolean;

    variable addr : std_logic_vector(awaddr'range) := (others => '0');
    variable data : std_logic_vector(wdata'range) := (others => '0');
    variable id : std_logic_vector(rid'range) := (others => '0');
    variable len : natural := 0;
    variable size : std_logic_vector(arsize'range) := (others => '0');
    variable burst : std_logic_vector(arburst'range) := (others => '0');
    variable resp : axi_resp_t;
  begin
    -- Initialization
    rnd.InitSeed(rnd'instance_name);
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
        while rnd.Uniform(0.0, 1.0) > read_high_probability loop
          wait until rising_edge(aclk);
        end loop;
        
        addr := pop_std_ulogic_vector(request_msg);

        if msg_type = bus_read_msg then 
          len := 0;
          size := get_full_size;
          burst := axi_burst_type_fixed;
          id(id'range) := (others => '0');
        elsif msg_type = bus_burst_read_msg then 
          len := pop_integer(request_msg) - 1; -- bring bus burst down to axi zero based indexing
          size := get_full_size;
          burst := axi_burst_type_incr;
          id(id'range) := (others => '0');
        elsif msg_type = axi_read_msg then 
          len := 0;
          size := pop_std_ulogic_vector(request_msg);
          burst := axi_burst_type_fixed;
          id := pop_std_ulogic_vector(request_msg)(arid'length -1 downto 0);
        elsif msg_type = axi_burst_read_msg then 
          len := to_integer(unsigned(pop_std_ulogic_vector(request_msg)));
          size := pop_std_ulogic_vector(request_msg);
          burst := pop_std_ulogic_vector(request_msg);
          id := pop_std_ulogic_vector(request_msg)(arid'length -1 downto 0);
        end if;

        araddr <= addr;
        push_std_ulogic_vector(request_msg, addr);

        arlen <= std_logic_vector(to_unsigned(len, arlen'length));
        push_integer(request_msg, len);

        arsize <= size;
        push_std_ulogic_vector(request_msg, size);

        arburst <= burst;
        push_std_ulogic_vector(request_msg, burst);

        arid <= id;
        push_std_ulogic_vector(request_msg, id);

        resp := pop_std_ulogic_vector(request_msg) when is_axi_msg(msg_type) else axi_resp_okay;
        push(request_msg, resp);

        push(read_reply_queue, request_msg);

        arvalid <= '1';
        wait until (arvalid and arready) = '1' and rising_edge(aclk);
        arvalid <= '0';
        drive_ar_invalid;

      elsif is_write(msg_type) then
        while rnd.Uniform(0.0, 1.0) > write_high_probability loop
          wait until rising_edge(aclk);
        end loop;
        addr := pop_std_ulogic_vector(request_msg);
        push_std_ulogic_vector(request_msg, addr);
        awaddr <= addr;
        data := pop_std_ulogic_vector(request_msg);
        push_std_ulogic_vector(request_msg, data);
        wdata <= data;
        wstrb <= pop_std_ulogic_vector(request_msg);

        if(is_axi_msg(msg_type)) then 
          awlen <= pop_std_ulogic_vector(request_msg);
          awsize <= pop_std_ulogic_vector(request_msg);
          awburst <= pop_std_ulogic_vector(request_msg);

          id := pop_std_ulogic_vector(request_msg)(awid'length -1 downto 0);
          push_std_ulogic_vector(request_msg, id);
          awid <= id;

          wlast <= pop_std_ulogic(request_msg);
        end if;

        resp := pop_std_ulogic_vector(request_msg) when is_axi_msg(msg_type) else axi_resp_okay;
        push_std_ulogic_vector(request_msg, resp);
        push(write_reply_queue, request_msg);

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
      else
        unexpected_msg_type(msg_type);
      end if;

      idle <= true;
    end loop;
  end process;

  -- Reply in separate process do not destroy alignment with the clock
  read_reply : process
    variable request_msg, reply_msg : msg_t;
    variable msg_type : msg_type_t;
    variable addr : std_logic_vector(awaddr'range) := (others => '0');
    variable id : std_logic_vector(rid'range) := (others => '0');
    variable len : natural := 0;
    variable size : std_logic_vector(arsize'range) := (others => '0');
    variable burst : std_logic_vector(arburst'range) := (others => '0');
    variable resp : axi_resp_t;

    procedure write_debug is
      begin
        if is_visible(bus_handle.p_logger, debug) then
          debug(bus_handle.p_logger,
                "Read 0x" & to_hstring(rdata) &
                  " from address 0x" & to_hstring(addr));
        end if;
      end procedure;
  begin
    
    rready <= '1';
    wait until (rvalid and rready) = '1' and rising_edge(aclk);
    
    reply_msg := new_msg;
    request_msg := pop(read_reply_queue);
    msg_type := message_type(request_msg);

    addr := pop_std_ulogic_vector(request_msg);
    len := pop_integer(request_msg);
    size := pop_std_ulogic_vector(request_msg);
    burst := pop_std_ulogic_vector(request_msg);
    id := pop_std_ulogic_vector(request_msg);
    resp := pop(request_msg);

    if msg_type = bus_burst_read_msg or msg_type =  axi_burst_read_msg then 
      push_integer(reply_msg, len + 1);  -- bring axi burst up to bus one based indexing
    end if;

    -- first iteration
    check_axi_id(bus_handle, rid, id, "rid");
    check_axi_resp(bus_handle, rresp, resp, "rresp");
    write_debug;
    push_std_ulogic_vector(reply_msg, rdata);

    -- burst iterations
    for i in 0 to len - 1 loop
      wait until (rvalid and rready) = '1' and rising_edge(aclk);
      check_axi_id(bus_handle, rid, id, "rid");
      check_axi_resp(bus_handle, rresp, resp, "rresp");
      write_debug;
      push_std_ulogic_vector(reply_msg, rdata);
    end loop;

    reply(net, request_msg, reply_msg);
    delete(request_msg);
  end process;

  -- Reply in separate process do not destroy alignment with the clock
  write_reply : process
    variable request_msg, reply_msg : msg_t;
    variable msg_type : msg_type_t;
    variable addr : std_logic_vector(awaddr'range) := (others => '0');
    variable data : std_logic_vector(wdata'range) := (others => '0');
    variable resp : axi_resp_t;
    variable id : std_logic_vector(rid'range) := (others => '0');
  begin
    
    bready <= '1';
    wait until (bvalid and bready) = '1' and rising_edge(aclk);
    bready <= '0';

    request_msg := pop(write_reply_queue);
    msg_type := message_type(request_msg);
    addr := pop_std_ulogic_vector(request_msg);
    data := pop_std_ulogic_vector(request_msg);

    if(is_axi_msg(msg_type)) then
      id := pop_std_ulogic_vector(request_msg);
      check_axi_id(bus_handle, bid, id, "bid");
    end if;

    resp := pop_std_ulogic_vector(request_msg);
    check_axi_resp(bus_handle, bresp, resp, "bresp");

    if is_visible(bus_handle.p_logger, debug) then
      debug(bus_handle.p_logger,
            "Wrote 0x" & to_hstring(data) &
              " to address 0x" & to_hstring(addr));
    end if;

    delete(request_msg);
  end process;

end architecture;
