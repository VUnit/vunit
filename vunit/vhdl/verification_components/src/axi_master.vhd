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
    axi_master_handle : axi_master_t
  );
  port (
    aclk : in std_logic;
    areset_n : in std_logic;
    
    arvalid : out std_logic := '0';
    arready : in std_logic;
    arid : out std_logic_vector;
    araddr : out std_logic_vector(address_length(axi_master_handle.p_bus_handle) - 1 downto 0) := (others => '0');
    arlen : out std_logic_vector;
    arsize : out std_logic_vector;
    arburst : out axi_burst_type_t;

    rvalid : in std_logic;
    rready : out std_logic := '0';
    rid : in std_logic_vector;
    rdata : in std_logic_vector(data_length(axi_master_handle.p_bus_handle) - 1 downto 0);
    rresp : in axi_resp_t;
    rlast : in std_logic;

    awvalid : out std_logic := '0';
    awready : in std_logic := '0';
    awid : out std_logic_vector;
    awaddr : out std_logic_vector(address_length(axi_master_handle.p_bus_handle) - 1 downto 0) := (others => '0');
    awlen : out std_logic_vector;
    awsize : out std_logic_vector;
    awburst : out axi_burst_type_t;

    wvalid : out std_logic;
    wready : in std_logic := '0';
    wdata : out std_logic_vector(data_length(axi_master_handle.p_bus_handle) - 1 downto 0) := (others => '0');
    wstrb : out std_logic_vector(byte_enable_length(axi_master_handle.p_bus_handle) - 1 downto 0) := (others => '0');
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
    receive(net, axi_master_handle.p_bus_handle.p_actor, request_msg);
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
      if axi_master_handle.p_drive_invalid then
        araddr <= (araddr'range => axi_master_handle.p_drive_invalid_val);
        arlen <= (arlen'range => axi_master_handle.p_drive_invalid_val);
        arsize <= (arsize'range => axi_master_handle.p_drive_invalid_val);
        arburst <= (arburst'range => axi_master_handle.p_drive_invalid_val);
        arid <= (arid'range => axi_master_handle.p_drive_invalid_val);
      end if;
    end procedure;

    procedure drive_aw_invalid is
    begin
      if axi_master_handle.p_drive_invalid then
        awaddr <= (awaddr'range => axi_master_handle.p_drive_invalid_val);
        awlen <= (awlen'range => axi_master_handle.p_drive_invalid_val);
        awsize <= (awsize'range => axi_master_handle.p_drive_invalid_val);
        awburst <= (awburst'range => axi_master_handle.p_drive_invalid_val);
        awid <= (arid'range => axi_master_handle.p_drive_invalid_val);
      end if;
    end procedure;

    procedure drive_w_invalid is
    begin
      if axi_master_handle.p_drive_invalid then
        wlast <= axi_master_handle.p_drive_invalid_val;
        wdata <= (wdata'range => axi_master_handle.p_drive_invalid_val);
        wstrb <= (wstrb'range => axi_master_handle.p_drive_invalid_val);
      end if;
    end procedure;

    procedure drive_idle is
      begin
        arvalid <= '0';
        awvalid <= '0';
        wvalid <= '0';
        drive_ar_invalid;
        drive_aw_invalid;
        drive_w_invalid;
    end procedure;

    function get_full_read_size return std_logic_vector is
      begin
        return std_logic_vector(to_unsigned(integer(ceil(log2(real(rdata'length/8)))), arsize'length));
    end function;

    function get_full_write_size return std_logic_vector is
      begin
        return std_logic_vector(to_unsigned(integer(ceil(log2(real(wdata'length/8)))), awsize'length));
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
    variable byteenable : std_logic_vector(wstrb'range) := (others => '0');
    variable resp : axi_resp_t;
  begin
    -- Initialization
    rnd.InitSeed(rnd'instance_name);
    drive_idle;

    loop
      wait until rising_edge(aclk) and not is_empty(message_queue) and areset_n = '1';
      idle <= false;
      wait for 0 ps;

      request_msg := pop(message_queue);
      msg_type := message_type(request_msg);

      if is_read(msg_type) then
        while rnd.Uniform(0.0, 1.0) > axi_master_handle.p_read_high_probability and areset_n = '1' loop
          wait until rising_edge(aclk) or areset_n = '0';
        end loop;
        
        addr := pop_std_ulogic_vector(request_msg);

        if msg_type = bus_read_msg then 
          len := 0;
          size := get_full_read_size;
          burst := axi_burst_type_fixed;
          id(id'range) := (others => '0');
        elsif msg_type = bus_burst_read_msg then 
          len := pop_integer(request_msg) - 1; -- bring bus burst down to axi zero based indexing
          size := get_full_read_size;
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
        wait until ((arvalid and arready) = '1' and rising_edge(aclk)) or areset_n = '0';
        arvalid <= '0';
        drive_ar_invalid;

      elsif is_write(msg_type) then
        while rnd.Uniform(0.0, 1.0) > axi_master_handle.p_write_high_probability and areset_n = '1' loop
          wait until rising_edge(aclk) or areset_n = '0';
        end loop;

        addr := pop_std_ulogic_vector(request_msg);
        
        if msg_type = bus_write_msg then 
          data := pop_std_ulogic_vector(request_msg);
          byteenable := pop_std_ulogic_vector(request_msg);
          len := 0;
          size := get_full_write_size;
          burst := axi_burst_type_fixed;
          id(id'range) := (others => '0');
          resp :=  axi_resp_okay;
        elsif msg_type = bus_burst_write_msg then
          byteenable(byteenable'range) := (others => '1'); -- not set in bus master pkg
          len := pop_integer(request_msg) - 1; -- bring bus burst down to axi zero based indexing
          data := pop_std_ulogic_vector(request_msg);
          size := get_full_write_size;
          burst := axi_burst_type_incr;
          id(id'range) := (others => '0');
          resp :=  axi_resp_okay;
        elsif msg_type = axi_write_msg then 
          data := pop_std_ulogic_vector(request_msg);
          byteenable := pop_std_ulogic_vector(request_msg);
          len := 0;
          size := pop_std_ulogic_vector(request_msg);
          burst := axi_burst_type_fixed;
          id := pop_std_ulogic_vector(request_msg)(arid'length -1 downto 0);
          resp := pop_std_ulogic_vector(request_msg);
        elsif msg_type = axi_burst_write_msg then 
          byteenable := pop_std_ulogic_vector(request_msg);
          len := to_integer(unsigned(pop_std_ulogic_vector(request_msg)));
          size := pop_std_ulogic_vector(request_msg);
          burst := pop_std_ulogic_vector(request_msg);
          id := pop_std_ulogic_vector(request_msg)(arid'length -1 downto 0);
          resp := pop_std_ulogic_vector(request_msg);
          data := pop_std_ulogic_vector(request_msg);
        end if;

        w_done := false;
        aw_done := false;

        -- first iteration
        awvalid <= '1';
        awaddr <= addr;
        awlen <= std_logic_vector(to_unsigned(len, awlen'length));
        awsize <= size;
        awburst <= burst;
        awid <= id;

        wvalid <= '1';
        wdata <= data;
        wstrb <= byteenable;
        wlast <= '1' when len = 0 else '0';

        while not (w_done and aw_done) loop
          wait until (((awvalid and awready) = '1' or (wvalid and wready) = '1') and rising_edge(aclk)) or areset_n = '0';

          if areset_n = '0' then 
            exit;
          end if;

          if (awvalid and awready) = '1' then
            awvalid <= '0';
            drive_aw_invalid;
            aw_done := true;
          end if;

          if (wvalid and wready) = '1' then

            if len = 0 then 
              wvalid <= '0';
              drive_w_invalid;
              w_done := true;
            else
            -- burst iterations
              len := len - 1;
              data := pop_std_ulogic_vector(request_msg);
              wdata <= data;
              wstrb <= byteenable;
              wlast <= '1' when len = 0 else '0';
            end if;

            if is_visible(axi_master_handle.p_bus_handle.p_logger, debug) then
              debug(axi_master_handle.p_bus_handle.p_logger,
                    "Wrote 0x" & to_hstring(data) &
                      " to address 0x" & to_hstring(addr));
            end if;
          end if;

        end loop;

        if areset_n = '1' then 
          push_std_ulogic_vector(request_msg, addr);
          push_std_ulogic_vector(request_msg, id);
          push_std_ulogic_vector(request_msg, resp);
          push(write_reply_queue, request_msg);
        end if;

      else
        unexpected_msg_type(msg_type);
      end if;

      if areset_n = '0' then 
        drive_idle;
        flush(read_reply_queue);
        flush(write_reply_queue);
        flush(message_queue);
        wait for 0 ps;
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
        if is_visible(axi_master_handle.p_bus_handle.p_logger, debug) then
          debug(axi_master_handle.p_bus_handle.p_logger,
                "Read 0x" & to_hstring(rdata) &
                  " from address 0x" & to_hstring(addr));
        end if;
      end procedure;
  begin
    
    rready <= '1';
    wait until ((rvalid and rready) = '1' and rising_edge(aclk));
    
    if areset_n = '1' then 
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
      check_axi_id(axi_master_handle.p_bus_handle, rid, id, "rid");
      check_axi_resp(axi_master_handle.p_bus_handle, rresp, resp, "rresp");
      write_debug;
      push_std_ulogic_vector(reply_msg, rdata);

      -- burst iterations
      for i in 0 to len - 1 loop
        wait until ((rvalid and rready) = '1' and rising_edge(aclk)) or areset_n = '0';
        if areset_n = '0' then 
          exit;
        end if;
        check_axi_id(axi_master_handle.p_bus_handle, rid, id, "rid");
        check_axi_resp(axi_master_handle.p_bus_handle, rresp, resp, "rresp");
        write_debug;
        push_std_ulogic_vector(reply_msg, rdata);
      end loop;

      if areset_n = '1' then 
        reply(net, request_msg, reply_msg);
        delete(request_msg);
      end if;
    end if;
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
    if areset_n = '1' then 
      bready <= '0';

      request_msg := pop(write_reply_queue);
      msg_type := message_type(request_msg);
      addr := pop_std_ulogic_vector(request_msg);
      id := pop_std_ulogic_vector(request_msg);
      resp := pop_std_ulogic_vector(request_msg);

      check_axi_id(axi_master_handle.p_bus_handle, bid, id, "bid");
      check_axi_resp(axi_master_handle.p_bus_handle, bresp, resp, "bresp");

      delete(request_msg);
    end if;
  end process;

end architecture;
