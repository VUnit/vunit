-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com
-- Author David Martin david.martin@phios.group


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pkg.all;
use work.bus_master_pkg.all;
use work.com_pkg.send;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;

package axi_master_pkg is

  constant axi_read_msg : msg_type_t := new_msg_type("read axi ");
  constant axi_write_msg : msg_type_t := new_msg_type("write axi ");
  constant axi_burst_read_msg : msg_type_t := new_msg_type("read axi burst ");
  constant axi_burst_write_msg : msg_type_t := new_msg_type("write axi burst ");

  -- Blocking: Write the bus
  procedure write_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant data : std_logic_vector;
                          constant size : std_logic_vector;
                          constant id : std_logic_vector := "";
                          constant expected_bresp : axi_resp_t := axi_resp_okay;
                          -- default byte enable is all bytes
                          constant byte_enable : std_logic_vector := "");

  -- Blocking: Burst write the bus
  procedure burst_write_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant len : std_logic_vector;
                          constant size : std_logic_vector;
                          constant burst : axi_burst_type_t;
                          constant data : queue_t;
                          constant id : std_logic_vector := "";
                          constant expected_bresp : axi_resp_t := axi_resp_okay;
                          -- default byte enable is all bytes
                          constant byte_enable : std_logic_vector := "");

  -- Non blocking: Read the bus returning a reference to the future reply
  procedure read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant size : std_logic_vector;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          variable reference : inout bus_reference_t);

  -- Blocking: read bus with immediate reply
  procedure read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant size : std_logic_vector;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          variable data : inout std_logic_vector);

  -- Blocking: Read bus and check result against expected data
  procedure check_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant size : std_logic_vector;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          constant expected : std_logic_vector;
                          constant msg : string := "");

  -- Non blocking: Read the bus returning a reference to the future reply
  procedure burst_read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant len : std_logic_vector;
                          constant size : std_logic_vector;
                          constant burst : axi_burst_type_t;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          variable reference : inout bus_reference_t);

  -- Blocking: read bus with immediate reply
  procedure burst_read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant len : std_logic_vector;
                          constant size : std_logic_vector;
                          constant burst : axi_burst_type_t;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          constant data : queue_t);

  -- Blocking: Read bus and check result against expected data
  -- procedure burst_check_axi(signal net : inout network_t;
  --                          constant bus_handle : bus_master_t;
  --                          constant address : std_logic_vector;
  --                          constant len : std_logic_vector;
  --                          constant size : std_logic_vector;
  --                          constant burst : axi_burst_type_t;
  --                          constant id : std_logic_vector := "";
  --                          constant expected_rresp : axi_resp_t := axi_resp_okay;
  --                          constant expected : std_logic_vector;
  --                          constant msg : string := "");

  function is_read(msg_type : msg_type_t) return boolean;
  function is_write(msg_type : msg_type_t) return boolean;
  function is_axi_msg(msg_type : msg_type_t) return boolean;

  function len_length(bus_handle : bus_master_t) return natural;
  function id_length(bus_handle : bus_master_t) return natural;
  function size_length(bus_handle : bus_master_t) return natural;
end package;

package body axi_master_pkg is

  procedure write_axi(signal net : inout network_t;
                            constant bus_handle : bus_master_t;
                            constant address : std_logic_vector;
                            constant data : std_logic_vector;
                            constant size : std_logic_vector;
                            constant id : std_logic_vector := "";
                            constant expected_bresp : axi_resp_t := axi_resp_okay;
                            -- default byte enable is all bytes
                            constant byte_enable : std_logic_vector := "") is
    variable request_msg : msg_t := new_msg(axi_write_msg);
    variable full_data : std_logic_vector(bus_handle.p_data_length - 1 downto 0) := (others => '0');
    variable full_address : std_logic_vector(bus_handle.p_address_length - 1 downto 0) := (others => '0');
    variable full_byte_enable : std_logic_vector(byte_enable_length(bus_handle) - 1 downto 0);
    variable full_len : std_logic_vector(len_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_size : std_logic_vector(size_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_id : std_logic_vector(id_length(bus_handle) - 1 downto 0) := (others => '0');
  begin
    full_address(address'length - 1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);

    full_data(data'length - 1 downto 0) := data;
    push_std_ulogic_vector(request_msg, full_data);

    if byte_enable = "" then
      full_byte_enable := (others => '1');
    else
      full_byte_enable(byte_enable'length - 1 downto 0) := byte_enable;
    end if;
    push_std_ulogic_vector(request_msg, full_byte_enable);

    full_size(size'length - 1 downto 0) := size;
    push_std_ulogic_vector(request_msg, full_size);

    if id = "" then
      full_id := (others => '0');
    else
      full_id(id'length - 1 downto 0) := id;
    end if;
    push_std_ulogic_vector(request_msg, full_id);

    push_std_ulogic_vector(request_msg, expected_bresp);
    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure burst_write_axi(signal net : inout network_t;
                           constant bus_handle : bus_master_t;
                           constant address : std_logic_vector;
                           constant len : std_logic_vector;
                           constant size : std_logic_vector;
                           constant burst : axi_burst_type_t;
                           constant data : queue_t;
                           constant id : std_logic_vector := "";
                           constant expected_bresp : axi_resp_t := axi_resp_okay;
                           -- default byte enable is all bytes
                           constant byte_enable : std_logic_vector := "") is
    variable request_msg : msg_t := new_msg(axi_burst_write_msg);
    variable full_data : std_logic_vector(bus_handle.p_data_length - 1 downto 0) := (others => '0');
    variable full_address : std_logic_vector(bus_handle.p_address_length - 1 downto 0) := (others => '0');
    variable full_byte_enable : std_logic_vector(byte_enable_length(bus_handle) - 1 downto 0);
    variable full_len : std_logic_vector(len_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_size : std_logic_vector(size_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_id : std_logic_vector(id_length(bus_handle) - 1 downto 0) := (others => '0');
  begin
    full_address(address'length - 1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);

    if byte_enable = "" then
      full_byte_enable := (others => '1');
    else
      full_byte_enable(byte_enable'length - 1 downto 0) := byte_enable;
    end if;
    push_std_ulogic_vector(request_msg, full_byte_enable);

    full_len(len'length - 1 downto 0) := len;
    push_std_ulogic_vector(request_msg, full_len);

    full_size(size'length - 1 downto 0) := size;
    push_std_ulogic_vector(request_msg, full_size);

    push_std_ulogic_vector(request_msg, burst);

    if id = "" then
      full_id := (others => '0');
    else
    full_id(id'length - 1 downto 0) := id;
    end if;
    push_std_ulogic_vector(request_msg, full_id);

    push_std_ulogic_vector(request_msg, expected_bresp);

    for i in 0 to to_integer(unsigned(len)) loop
      full_data(bus_handle.p_data_length-1 downto 0) := pop(data);
      push_std_ulogic_vector(request_msg, full_data);
    end loop;

    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant size : std_logic_vector;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          variable reference : inout bus_reference_t) is
    variable full_address : std_logic_vector(bus_handle.p_address_length - 1 downto 0) := (others => '0');
    variable full_size : std_logic_vector(size_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_id : std_logic_vector(id_length(bus_handle) - 1 downto 0) := (others => '0');
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(axi_read_msg);
    full_address(address'length - 1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);

    full_size(size'length - 1 downto 0) := size;
    push_std_ulogic_vector(request_msg, full_size);

    if id = "" then
      full_id := (others => '0');
    else
    full_id(id'length - 1 downto 0) := id;
    end if;
    push_std_ulogic_vector(request_msg, full_id);

    push_std_ulogic_vector(request_msg, expected_rresp);
    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant size : std_logic_vector;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          variable data : inout std_logic_vector) is
    variable reference : bus_reference_t;
  begin
    read_axi(net, bus_handle, address, size, id, expected_rresp, reference);
    await_read_bus_reply(net, reference, data);
  end procedure;

  procedure check_axi(signal net : inout network_t;
                           constant bus_handle : bus_master_t;
                           constant address : std_logic_vector;
                           constant size : std_logic_vector;
                           constant id : std_logic_vector := "";
                           constant expected_rresp : axi_resp_t := axi_resp_okay;
                           constant expected : std_logic_vector;
                           constant msg : string := "") is
    variable data : std_logic_vector(bus_handle.p_data_length - 1 downto 0);
    variable edata : std_logic_vector(data'range) := (others => '0');

    impure function error_prefix return string is
    begin
      if msg = "" then
        return "check_bus(x""" & to_hstring(address) & """)";
      else
        return msg;
      end if;
    end;

    impure function base_error return string is
    begin
      return error_prefix & " - Got x""" & to_hstring(data) & """ expected x""" & to_hstring(edata) & """";
    end;
  begin

    edata(expected'length - 1 downto 0) := expected;

    read_axi(net, bus_handle, address, size, id, expected_rresp, data);
    if not std_match(data, edata) then
      failure(bus_handle.p_logger, base_error);
    end if;
  end procedure;

  procedure burst_read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant len : std_logic_vector;
                          constant size : std_logic_vector;
                          constant burst : axi_burst_type_t;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          variable reference : inout bus_reference_t) is
    variable full_address : std_logic_vector(bus_handle.p_address_length - 1 downto 0) := (others => '0');
    variable full_len : std_logic_vector(len_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_size : std_logic_vector(size_length(bus_handle) - 1 downto 0) := (others => '0');
    variable full_id : std_logic_vector(id_length(bus_handle) - 1 downto 0) := (others => '0');
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(axi_burst_read_msg);
    full_address(address'length - 1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);

    full_len(len'length - 1 downto 0) := len;
    push_std_ulogic_vector(request_msg, full_len);

    full_size(size'length - 1 downto 0) := size;
    push_std_ulogic_vector(request_msg, full_size);

    push_std_ulogic_vector(request_msg, burst);

    if id = "" then
      full_id := (others => '0');
    else
    full_id(id'length - 1 downto 0) := id;
    end if;
    push_std_ulogic_vector(request_msg, full_id);

    push_std_ulogic_vector(request_msg, expected_rresp);
    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure burst_read_axi(signal net : inout network_t;
                          constant bus_handle : bus_master_t;
                          constant address : std_logic_vector;
                          constant len : std_logic_vector;
                          constant size : std_logic_vector;
                          constant burst : axi_burst_type_t;
                          constant id : std_logic_vector := "";
                          constant expected_rresp : axi_resp_t := axi_resp_okay;
                          constant data : queue_t) is
    variable reference : bus_reference_t;
  begin
    burst_read_axi(net, bus_handle, address, len, size, burst, id, expected_rresp, reference);
    await_burst_read_bus_reply(net, bus_handle, data, reference);
  end procedure;

  -- procedure burst_check_axi(signal net : inout network_t;
  --                          constant bus_handle : bus_master_t;
  --                          constant address : std_logic_vector;
  --                          constant len : std_logic_vector;
  --                          constant size : std_logic_vector;
  --                          constant burst : axi_burst_type_t;
  --                          constant id : std_logic_vector := "";
  --                          constant expected_rresp : axi_resp_t := axi_resp_okay;
  --                          constant expected : std_logic_vector;
  --                          constant msg : string := "") is
  --   variable data : std_logic_vector(bus_handle.p_data_length - 1 downto 0);
  --   variable edata : std_logic_vector(data'range) := (others => '0');

  --   impure function error_prefix return string is
  --   begin
  --     if msg = "" then
  --       return "check_bus(x""" & to_hstring(address) & """)";
  --     else
  --       return msg;
  --     end if;
  --   end;

  --   impure function base_error return string is
  --   begin
  --     return error_prefix & " - Got x""" & to_hstring(data) & """ expected x""" & to_hstring(edata) & """";
  --   end;
  -- begin

  --   edata(expected'length - 1 downto 0) := expected;

  --   burst_read_axi(net, bus_handle, address, len, size, burst, id, expected_rresp, data);
  --   if not std_match(data, edata) then
  --     failure(bus_handle.p_logger, base_error);
  --   end if;
  -- end procedure;

  function is_read(msg_type : msg_type_t) return boolean is
  begin
    return msg_type = bus_read_msg or msg_type = axi_read_msg or msg_type = bus_burst_read_msg or msg_type = axi_burst_read_msg;
  end function;

  function is_write(msg_type : msg_type_t) return boolean is
  begin
    return msg_type = bus_write_msg or msg_type = axi_write_msg or msg_type = bus_burst_write_msg or msg_type = axi_burst_write_msg;
  end function;

  function is_axi_msg(msg_type : msg_type_t) return boolean is
  begin
    return msg_type = axi_read_msg or msg_type = axi_write_msg or msg_type = axi_burst_read_msg or msg_type = axi_burst_write_msg;
  end function;

  function len_length(bus_handle : bus_master_t) return natural is
  begin
    return 8;  -- TODO Add to bus_master_t?
  end;

  function id_length(bus_handle : bus_master_t) return natural is
  begin
    return 32; -- TODO Add to bus_master_t?
  end;

  function size_length(bus_handle : bus_master_t) return natural is
  begin
    return 3; -- TODO Add to bus_master_t?
  end;
end package body;
