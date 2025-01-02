-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.axi_statistics_pkg.axi_statistics_t;
use work.axi_statistics_pkg.deallocate;
use work.com_pkg.all;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.memory_pkg.memory_t;
use work.memory_pkg.to_vc_interface;

package axi_slave_pkg is
  subtype probability_t is real range 0.0 to 1.0;

  type axi_slave_t is record
    -- Private
    p_initial_address_fifo_depth : positive;
    p_initial_write_response_fifo_depth : positive;
    p_initial_check_4kbyte_boundary : boolean;
    p_initial_address_stall_probability : probability_t;
    p_initial_data_stall_probability : probability_t;
    p_initial_write_response_stall_probability : probability_t;
    p_initial_min_response_latency : delay_length;
    p_initial_max_response_latency : delay_length;
    p_actor : actor_t;
    p_memory : memory_t;
    p_logger : logger_t;
  end record;

  constant axi_slave_logger : logger_t := get_logger("vunit_lib:axi_slave_pkg");
  impure function new_axi_slave(memory : memory_t;
                                actor : actor_t := null_actor;
                                address_fifo_depth : positive := 1;
                                write_response_fifo_depth : positive := 1;
                                check_4kbyte_boundary : boolean := true;
                                address_stall_probability : probability_t := 0.0;
                                data_stall_probability : probability_t := 0.0;
                                write_response_stall_probability : probability_t := 0.0;
                                min_response_latency : delay_length := 0 ns;
                                max_response_latency : delay_length := 0 ns;
                                logger : logger_t := axi_slave_logger) return axi_slave_t;

  -- Get the logger used by the axi_slave
  function get_logger(axi_slave : axi_slave_t) return logger_t;

  -- Set the maximum number address channel tokens that can be queued
  procedure set_address_fifo_depth(signal net : inout network_t;
                                   axi_slave : axi_slave_t;
                                   depth : positive);

  -- Set the maximum number write responses that can be queued
  procedure set_write_response_fifo_depth(signal net : inout network_t;
                                          axi_slave : axi_slave_t;
                                          depth : positive);

  -- Set the address channel stall probability
  procedure set_address_stall_probability(signal net : inout network_t;
                                          axi_slave : axi_slave_t;
                                          probability : probability_t);

  -- Set the data channel stall probability
  procedure set_data_stall_probability(signal net : inout network_t;
                                       axi_slave : axi_slave_t;
                                       probability : probability_t);

  -- Set the write response stall probability
  procedure set_write_response_stall_probability(signal net : inout network_t;
                                                 axi_slave : axi_slave_t;
                                                 probability : probability_t);

  -- Set the response latency
  --
  -- For a write slave this is the time between the last write data
  -- and providing the write reponse. All write data is written to the
  -- memory model right before providing write response.
  -- Data address and expected value is still checked as soons as it arrives to
  -- the axi slave and is not delayed until the write response time.
  --
  -- For a read slave this is the time between the read burst arrival and the
  -- first provided read data
  --
  -- The response latency is randomly choosen in the uniform interval:
  -- [min_latency, max_latency]
  procedure set_response_latency(signal net : inout network_t;
                                 axi_slave : axi_slave_t;
                                 min_latency, max_latency : delay_length);

  -- Short hand for set_response_latency when min and max are the same
  procedure set_response_latency(signal net : inout network_t;
                                 axi_slave : axi_slave_t;
                                 latency : delay_length);

  procedure enable_4kbyte_boundary_check(signal net : inout network_t;
                                         axi_slave : axi_slave_t);
  procedure disable_4kbyte_boundary_check(signal net : inout network_t;
                                          axi_slave : axi_slave_t);

  -- Get statistics object from axi slave
  -- Dynamically allocates new statistics object which must he deallocated when
  -- used
  -- This procedure will automatically deallocate the input statistics object
  -- if it is not null
  procedure get_statistics(signal net : inout network_t;
                           axi_slave : axi_slave_t;
                           variable stat  : inout axi_statistics_t;
                           clear : boolean := false);

  -- Check that bursts are well behaved, that is that data channel traffic is
  -- as compact as possible

  -- For write:
  -- 1. awvalid never high without wvalid
  -- 2. wvalid never goes low during active burst
  -- 3. uses max awsize supported by data width
  -- 4. bready never low during active burst

  -- For read:
  -- 1. rready never low during active burst
  -- 2. uses max arsize supported by data width
  procedure enable_well_behaved_check(signal net : inout network_t; axi_slave : axi_slave_t);

  -- Private constants
  constant axi_slave_set_address_fifo_depth_msg : msg_type_t := new_msg_type("axi slave set address channel fifo depth");
  constant axi_slave_set_write_response_fifo_depth_msg : msg_type_t := new_msg_type("set write response fifo depth");
  constant axi_slave_set_address_stall_probability_msg : msg_type_t := new_msg_type("axi slave set address channel stall probability");
  constant axi_slave_set_data_stall_probability_msg : msg_type_t := new_msg_type("axi slave set data stall probability");
  constant axi_slave_set_write_response_stall_probability_msg : msg_type_t := new_msg_type("axi slave set write response stall probability");
  constant axi_slave_set_response_latency_msg : msg_type_t := new_msg_type("axi slave response latency probability");
  constant axi_slave_configure_4kbyte_boundary_check_msg : msg_type_t := new_msg_type("axi slave configure 4kbyte boundary check");
  constant axi_slave_get_statistics_msg : msg_type_t := new_msg_type("axi slave get statistics");
  constant axi_slave_enable_well_behaved_check_msg : msg_type_t := new_msg_type("axi slave enable well behaved check");

end package;

package body axi_slave_pkg is
  impure function new_axi_slave(memory : memory_t;
                                actor : actor_t := null_actor;
                                address_fifo_depth : positive := 1;
                                write_response_fifo_depth : positive := 1;
                                check_4kbyte_boundary : boolean := true;
                                address_stall_probability : probability_t := 0.0;
                                data_stall_probability : probability_t := 0.0;
                                write_response_stall_probability : probability_t := 0.0;
                                min_response_latency : delay_length := 0 ns;
                                max_response_latency : delay_length := 0 ns;
                                logger : logger_t := axi_slave_logger) return axi_slave_t is
    variable actor_tmp : actor_t := null_actor;
  begin
    if actor = null_actor then
      actor_tmp := new_actor;
    else
      actor_tmp := actor;
    end if;
    return (p_actor => actor_tmp,
            p_initial_address_fifo_depth => address_fifo_depth,
            p_initial_write_response_fifo_depth => write_response_fifo_depth,
            p_initial_check_4kbyte_boundary => check_4kbyte_boundary,
            p_initial_address_stall_probability => address_stall_probability,
            p_initial_data_stall_probability => data_stall_probability,
            p_initial_write_response_stall_probability => write_response_stall_probability,
            p_initial_min_response_latency => min_response_latency,
            p_initial_max_response_latency => max_response_latency,
            p_memory => to_vc_interface(memory, logger),
            p_logger => logger);
  end;

  function get_logger(axi_slave : axi_slave_t) return logger_t is
  begin
    return axi_slave.p_logger;
  end;

  procedure set_address_fifo_depth(signal net : inout network_t;
                                   axi_slave : axi_slave_t;
                                   depth : positive) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_set_address_fifo_depth_msg);
    push(request_msg, depth);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on set_address_fifo_depth command";
  end;

  procedure set_write_response_fifo_depth(signal net : inout network_t;
                                          axi_slave : axi_slave_t;
                                          depth : positive) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_set_write_response_fifo_depth_msg);
    push(request_msg, depth);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on set_write_response_fifo_depth command";
  end;

  procedure set_address_stall_probability(signal net : inout network_t;
                                          axi_slave : axi_slave_t;
                                          probability : probability_t) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_set_address_stall_probability_msg);
    push_real(request_msg, probability);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on set_address_stall_probability command";
  end;

  procedure set_data_stall_probability(signal net : inout network_t;
                                       axi_slave : axi_slave_t;
                                       probability : probability_t) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_set_data_stall_probability_msg);
    push_real(request_msg, probability);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on set_data_stall_probability command";
  end;

  procedure set_write_response_stall_probability(signal net : inout network_t; axi_slave : axi_slave_t;
                                                 probability : probability_t) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_set_write_response_stall_probability_msg);
    push_real(request_msg, probability);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on set_write_response_stall_probability command";
  end;

  procedure configure_4kbyte_boundary_check(signal net : inout network_t;
                                            axi_slave : axi_slave_t;
                                            value : boolean) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_configure_4kbyte_boundary_check_msg);
    push_boolean(request_msg, value);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on configure_4kbyte_boundary_check command";
  end;

  procedure set_response_latency(signal net : inout network_t;
                                 axi_slave : axi_slave_t;
                                 min_latency, max_latency : delay_length) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_set_response_latency_msg);
    push_time(request_msg, min_latency);
    push_time(request_msg, max_latency);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on set_response_latency command";
  end;

  -- Short hand for set_response_latency when min and max are the same
  procedure set_response_latency(signal net : inout network_t;
                                 axi_slave : axi_slave_t;
                                 latency : delay_length) is
  begin
    set_response_latency(net, axi_slave, latency, latency);
  end;

  procedure enable_4kbyte_boundary_check(signal net : inout network_t;
                                         axi_slave : axi_slave_t) is
  begin
    configure_4kbyte_boundary_check(net, axi_slave, true);
  end;

  procedure disable_4kbyte_boundary_check(signal net : inout network_t;
                                          axi_slave : axi_slave_t) is
  begin
    configure_4kbyte_boundary_check(net, axi_slave, false);
  end;


  procedure get_statistics(signal net : inout network_t;
                           axi_slave : axi_slave_t;
                           variable stat  : inout axi_statistics_t;
                           clear : boolean := false) is
    variable request_msg, reply_msg : msg_t;
  begin
    deallocate(stat);
    request_msg := new_msg(axi_slave_get_statistics_msg);
    push_boolean(request_msg, clear);
    send(net, axi_slave.p_actor, request_msg);
    receive_reply(net, request_msg, reply_msg);
    stat := (p_count_by_burst_length => pop_integer_vector_ptr_ref(reply_msg));
    delete(request_msg);
    delete(reply_msg);
  end;

  procedure enable_well_behaved_check(signal net : inout network_t;
                                      axi_slave : axi_slave_t) is
    variable request_msg : msg_t;
    variable ack : boolean;
  begin
    request_msg := new_msg(axi_slave_enable_well_behaved_check_msg);
    request(net, axi_slave.p_actor, request_msg, ack);
    assert ack report "Failed on msg_enable_well_behaved_check command";
  end;
end package body;
