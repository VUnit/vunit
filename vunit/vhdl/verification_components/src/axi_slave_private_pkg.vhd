-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Private support package for axi_{read, write}_slave.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.axi_pkg.all;
use work.axi_slave_pkg.all;
use work.axi_statistics_pkg.all;
use work.bus_master_pkg.bus_master_t;
use work.com_pkg.receive;
use work.com_pkg.reply;
use work.com_pkg.acknowledge;
use work.com_types_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;

package axi_slave_private_pkg is

  type axi_burst_t is record
    id : integer;
    address : integer;
    length : integer;
    size : integer;
    burst_type : axi_burst_type_t;

    -- A running counter for each processed burst
    -- Referring to this index for all burst related debug prints
    index : natural;
  end record;

  impure function describe_burst(burst : axi_burst_t) return string;

  type axi_slave_type_t is (write_slave,
                            read_slave);

  type axi_slave_private_t is protected
    procedure init(axi_slave : axi_slave_t;
                   axi_slave_type : axi_slave_type_t;
                   max_id : natural;
                   data : std_logic_vector);
    impure function get_actor return actor_t;

    procedure set_address_fifo_depth(depth : positive);
    procedure set_write_response_fifo_depth(depth : positive);
    procedure set_address_stall_probability(probability : probability_t);
    procedure set_data_stall_probability(probability : probability_t);
    procedure set_write_response_stall_probability(probability : probability_t);
    procedure set_min_response_latency(latency : delay_length);
    procedure set_max_response_latency(latency : delay_length);
    procedure set_check_4kbyte_boundary(value : boolean);
    procedure enable_well_behaved_check;
    impure function should_check_well_behaved return boolean;
    impure function should_stall_address return boolean;
    impure function should_stall_data return boolean;
    impure function should_stall_write_response return boolean;

    impure function create_burst(axid : std_logic_vector;
                                 axaddr : std_logic_vector;
                                 axlen : std_logic_vector;
                                 axsize : std_logic_vector;
                                 axburst : axi_burst_type_t) return axi_burst_t;

    procedure push_burst(burst : axi_burst_t);
    impure function pop_burst return axi_burst_t;
    impure function burst_queue_full return boolean;
    impure function burst_queue_empty return boolean;
    impure function burst_queue_length return natural;

    impure function resp_queue_full return boolean;
    impure function resp_queue_empty return boolean;
    impure function resp_queue_length return natural;
    procedure push_resp(burst : axi_burst_t);
    impure function pop_resp return axi_burst_t;

    procedure finish_burst(burst : axi_burst_t);

    procedure push_random_response_time;
    impure function pop_response_time return time;

    procedure fail(msg : string);
    procedure check_4kbyte_boundary(burst : axi_burst_t);
    impure function data_size return integer;

    impure function get_statistics return axi_statistics_t;
    procedure clear_statistics;
  end protected;

  procedure main_loop(variable self : inout axi_slave_private_t;
                      signal net : inout network_t);

  procedure check_axi_resp(bus_handle : bus_master_t; got, expected : axi_resp_t; msg : string);
end package;


package body axi_slave_private_pkg is

  impure function describe_burst(burst : axi_burst_t) return string is
  begin
    return "#" & to_string(burst.index) & " for id " & to_string(burst.id);
  end;

  procedure push_axi_burst(queue : queue_t; burst : axi_burst_t);
  impure function pop_axi_burst(queue : queue_t) return axi_burst_t;

  type axi_slave_private_t is protected body
    variable p_axi_slave : axi_slave_t;
    variable p_axi_slave_type : axi_slave_type_t;
    variable p_data_size : integer;
    variable p_max_id : natural;
    variable p_id_indexes : integer_vector_ptr_t;
    variable p_burst_queue_max_length : natural;
    variable p_burst_queue : queue_t;
    variable p_burst_queue_length : natural;
    variable p_resp_queue_max_length : natural;
    variable p_resp_queue : queue_t;
    variable p_resp_queue_length : natural;
    variable p_check_4kbyte_boundary : boolean;
    variable p_rnd : RandomPType;
    variable p_addr_stall_prob : probability_t;
    variable p_data_stall_prob : probability_t;
    variable p_wresp_stall_prob : probability_t;
    variable p_min_response_latency : delay_length;
    variable p_max_response_latency : delay_length;
    variable p_response_time_queue : queue_t;
    variable p_check_well_behaved : boolean;
    variable p_statistics : axi_statistics_t;

    procedure init(axi_slave : axi_slave_t;
                   axi_slave_type : axi_slave_type_t;
                   max_id : natural;
                   data : std_logic_vector) is
    begin
      p_axi_slave := axi_slave;
      p_axi_slave_type := axi_slave_type;
      p_data_size := data'length/8;
      p_max_id := max_id;
      p_id_indexes := new_integer_vector_ptr(length => max_id+1, value => 0);
      p_burst_queue_max_length := axi_slave.p_initial_address_fifo_depth;
      p_burst_queue := new_queue;
      p_burst_queue_length := 0;
      p_resp_queue_max_length := axi_slave.p_initial_write_response_fifo_depth;
      p_resp_queue := new_queue;
      p_resp_queue_length := 0;
      p_check_4kbyte_boundary := axi_slave.p_initial_check_4kbyte_boundary;
      p_check_well_behaved := false;
      set_address_stall_probability(axi_slave.p_initial_address_stall_probability);
      set_data_stall_probability(axi_slave.p_initial_data_stall_probability);
      set_write_response_stall_probability(axi_slave.p_initial_write_response_stall_probability);
      p_response_time_queue := new_queue;
      set_min_response_latency(axi_slave.p_initial_min_response_latency);
      set_max_response_latency(axi_slave.p_initial_max_response_latency);
      p_statistics := new_axi_statistics;
    end;

    impure function get_actor return actor_t is
    begin
      return p_axi_slave.p_actor;
    end;

    procedure set_address_fifo_depth(depth : positive) is
    begin
      if burst_queue_length > depth then
        fail("New address fifo depth " & to_string(depth) &
             " is smaller than current content size " & to_string(burst_queue_length));
      else
        p_burst_queue_max_length := depth;
      end if;
    end procedure;

    procedure set_write_response_fifo_depth(depth : positive) is
    begin
      if resp_queue_length > depth then
        fail("New write response fifo depth " & to_string(depth) &
             " is smaller than current content size " & to_string(resp_queue_length));
      else
        p_resp_queue_max_length := depth;
      end if;
    end procedure;

    procedure set_address_stall_probability(probability : probability_t) is
    begin
      p_addr_stall_prob := probability;
    end;

    procedure set_data_stall_probability(probability : probability_t) is
    begin
      p_data_stall_prob := probability;
    end;

    procedure set_write_response_stall_probability(probability : probability_t) is
    begin
      p_wresp_stall_prob := probability;
    end;

    procedure set_min_response_latency(latency : delay_length) is
    begin
      p_min_response_latency := latency;
    end;

    procedure set_max_response_latency(latency : delay_length) is
    begin
      p_max_response_latency := latency;
    end;

    procedure set_check_4kbyte_boundary(value : boolean) is
    begin
      p_check_4kbyte_boundary := value;
    end;

    procedure enable_well_behaved_check is
    begin
      p_check_well_behaved := true;
    end;

    impure function should_check_well_behaved return boolean is
    begin
      return p_check_well_behaved;
    end;

    impure function should_stall(prob : probability_t) return boolean is
    begin
      -- Enhance performance when prob = 0.0
      return prob /= 0.0 and p_rnd.Uniform(0.0, 1.0) < prob;
    end;

    impure function should_stall_address return boolean is
    begin
      return should_stall(p_addr_stall_prob);
    end;

    impure function should_stall_data return boolean is
    begin
      return should_stall(p_data_stall_prob);
    end;

    impure function should_stall_write_response return boolean is
    begin
      return should_stall(p_wresp_stall_prob);
    end;

    impure function create_burst(axid : std_logic_vector;
                                 axaddr : std_logic_vector;
                                 axlen : std_logic_vector;
                                 axsize : std_logic_vector;
                                 axburst : axi_burst_type_t) return axi_burst_t is

      -- Return the correct prefix ar/aw depending on slave type
      impure function ax return string is
      begin
        case p_axi_slave_type is
          when read_slave => return "ar";
          when write_slave => return "aw";
        end case;
      end;

      -- Return the correct read/write burst description
      impure function description return string is
      begin
        case p_axi_slave_type is
          when read_slave => return "read burst";
          when write_slave => return "write burst";
        end case;
      end;

      impure function burst_string return string is
      begin

        if axburst = axi_burst_type_fixed then
          return "fixed";
        elsif axburst = axi_burst_type_incr then
          return "incr";
        elsif axburst = axi_burst_type_wrap then
          return "wrap";
        else
          return "undefined";
        end if;
      end;

      variable burst : axi_burst_t;
    begin
      burst.id := to_integer(unsigned(axid));
      burst.address := to_integer(unsigned(axaddr));
      burst.length := to_integer(unsigned(axlen)) + 1;
      burst.size := 2**to_integer(unsigned(axsize));
      burst.burst_type := axburst;
      assert burst.id <= p_max_id report "axi id to large";
      burst.index := get(p_id_indexes, burst.id);
      set(p_id_indexes, burst.id, burst.index + 1);

      if is_visible(p_axi_slave.p_logger, debug) then
        debug(p_axi_slave.p_logger,
              "Got " & description & " " & describe_burst(burst) &
              LF & ax & "id    = 0x" & to_hstring(axid) &
              LF & ax & "addr  = 0x" & to_hstring(axaddr) &
              LF & ax & "len   = " & to_string(to_integer(unsigned(to_01(axlen)))) &
              LF & ax & "size  = " & to_string(to_integer(unsigned(to_01(axsize)))) &
              LF & ax & "burst = " & burst_string & " (" & to_string(axburst) & ")"
              );
      end if;

      add_burst_length(p_statistics, burst.length);

      if burst.burst_type = axi_burst_type_wrap then
        fail("Wrapping burst type not supported");
      end if;

      if p_check_4kbyte_boundary then
        check_4kbyte_boundary(burst);
      end if;

      return burst;
    end function;

    procedure push_burst(burst : axi_burst_t) is
    begin
      push_axi_burst(p_burst_queue, burst);
      p_burst_queue_length := p_burst_queue_length + 1;
    end;

    impure function pop_burst return axi_burst_t is
      constant burst : axi_burst_t := pop_axi_burst(p_burst_queue);
    begin
      if is_visible(p_axi_slave.p_logger, debug) then
        case p_axi_slave_type is
          when write_slave =>
            debug(p_axi_slave.p_logger,
                  "Start accepting data for write burst " & describe_burst(burst));
          when read_slave =>
            debug(p_axi_slave.p_logger,
                  "Start providing data for read burst " & describe_burst(burst));
        end case;
      end if;
      p_burst_queue_length := p_burst_queue_length - 1;
      return burst;
    end;

    impure function burst_queue_full return boolean is
    begin
      return burst_queue_length = p_burst_queue_max_length;
    end;

    impure function burst_queue_empty return boolean is
    begin
      return burst_queue_length = 0;
    end;

    impure function burst_queue_length return natural is
    begin
      return p_burst_queue_length;
    end;

    procedure push_resp(burst : axi_burst_t) is
    begin
      push_axi_burst(p_resp_queue, burst);
      p_resp_queue_length := p_resp_queue_length + 1;
    end;

    impure function pop_resp return axi_burst_t is
      constant resp_burst : axi_burst_t := pop_axi_burst(p_resp_queue);
    begin
      if is_visible(p_axi_slave.p_logger, debug) then
        debug(p_axi_slave.p_logger,
              "Providing write response for burst " & describe_burst(resp_burst));
      end if;
      p_resp_queue_length := p_resp_queue_length - 1;
      return resp_burst;
    end;

    procedure finish_burst(burst : axi_burst_t) is
    begin
      if is_visible(p_axi_slave.p_logger, debug) then
        case p_axi_slave_type is
          when write_slave =>
            debug(p_axi_slave.p_logger,
                  "Accepted last data for write burst " & describe_burst(burst));
          when read_slave =>
            debug(p_axi_slave.p_logger,
                  "Providing last data for read burst " & describe_burst(burst));
        end case;
      end if;
    end;

    impure function random_response_latency return delay_length is
    begin
      if p_min_response_latency = p_max_response_latency then
        return p_min_response_latency;
      else
        return p_rnd.RandTime(p_min_response_latency, p_max_response_latency);
      end if;
    end;

    procedure push_random_response_time is
    begin
      push_time(p_response_time_queue, now + random_response_latency);
    end;

    impure function pop_response_time return time is
    begin
      return pop_time(p_response_time_queue);
    end;

    impure function resp_queue_full return boolean is
    begin
      return resp_queue_length = p_resp_queue_max_length;
    end;

    impure function resp_queue_empty return boolean is
    begin
      return resp_queue_length = 0;
    end;

    impure function resp_queue_length return natural is
    begin
      return p_resp_queue_length;
    end;

    procedure fail(msg : string) is
    begin
      failure(p_axi_slave.p_logger, msg);
    end;

    procedure check_4kbyte_boundary(burst : axi_burst_t) is
      variable first_address, last_address : integer;
      variable first_page, last_page : integer;
    begin
      first_address := burst.address - (burst.address mod data_size); -- Aligned
      last_address := first_address + burst.size*burst.length - 1;

      first_page := first_address / 4096;
      last_page := last_address / 4096;

      if first_page /= last_page then
        fail("Crossing 4KByte boundary. First page = "
             & integer'image(first_page) & " (" & to_string(first_address) & "/4096)"
             & ", last page = "
             & integer'image(last_page) & " (" & to_string(last_address) & "/4096)");
      end if;
    end procedure;

    impure function data_size return integer is
    begin
      return p_data_size;
    end;

    impure function get_statistics return axi_statistics_t is
    begin
      return copy(p_statistics);
    end;

    procedure clear_statistics is
    begin
      clear(p_statistics);
    end;

  end protected body;


  procedure push_axi_burst(queue : queue_t; burst : axi_burst_t) is
  begin
    push(queue, burst.id);
    push(queue, burst.address);
    push(queue, burst.length);
    push(queue, burst.size);
    push(queue, burst.index);
    push_boolean(queue, burst.burst_type = axi_burst_type_fixed);
  end;

  impure function pop_axi_burst(queue : queue_t) return axi_burst_t is
    variable burst : axi_burst_t;
  begin
    burst.id := pop(queue);
    burst.address := pop(queue);
    burst.length := pop(queue);
    burst.size := pop(queue);
    burst.index := pop(queue);

    if pop_boolean(queue) then
      burst.burst_type := axi_burst_type_fixed;
    else
      burst.burst_type := axi_burst_type_incr;
    end if;

    return burst;
  end;

  procedure main_loop(variable self : inout axi_slave_private_t;
                      signal net : inout network_t) is
    variable reply_msg, request_msg : msg_t;
    variable msg_type : msg_type_t;

    variable clear_stat : boolean;
    variable stat : axi_statistics_t;
  begin
    while true loop
      receive(net, self.get_actor, request_msg);
      msg_type := message_type(request_msg);

      if msg_type = axi_slave_set_address_fifo_depth_msg then
        self.set_address_fifo_depth(pop(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_set_write_response_fifo_depth_msg then
        self.set_write_response_fifo_depth(pop(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_set_address_stall_probability_msg then
        self.set_address_stall_probability(pop_real(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_set_data_stall_probability_msg then
        self.set_data_stall_probability(pop_real(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_set_write_response_stall_probability_msg then
        self.set_write_response_stall_probability(pop_real(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_set_response_latency_msg then
        self.set_min_response_latency(pop_time(request_msg));
        self.set_max_response_latency(pop_time(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_configure_4kbyte_boundary_check_msg then
        self.set_check_4kbyte_boundary(pop_boolean(request_msg));
        acknowledge(net, request_msg, true);

      elsif msg_type = axi_slave_get_statistics_msg then
        clear_stat := pop_boolean(request_msg);
        stat := self.get_statistics;

        if clear_stat then
          self.clear_statistics;
        end if;

        reply_msg := new_msg;
        push_integer_vector_ptr_ref(reply_msg, stat.p_count_by_burst_length);
        reply(net, request_msg, reply_msg);
        delete(request_msg);

      elsif msg_type = axi_slave_enable_well_behaved_check_msg then
        self.enable_well_behaved_check;
        acknowledge(net, request_msg, true);
      else
        unexpected_msg_type(msg_type);
      end if;

      delete(request_msg);
    end loop;
  end;

  function resp_to_string(resp : axi_resp_t) return string is
  begin
    case resp is
      when axi_resp_okay => return "OKAY";
      when axi_resp_exokay => return "EXOKAY";
      when axi_resp_slverr => return "SLVERR";
      when axi_resp_decerr => return "DECERR";
      when others => return "UNKNOWN";
    end case;
  end;

  procedure check_axi_resp(bus_handle : bus_master_t; got, expected : axi_resp_t; msg : string) is
    function describe(resp : axi_resp_t) return string is
    begin
      return resp_to_string(resp) & "(" & to_string(resp) & ")";
    end;
  begin
    if got /= expected then
      failure(bus_handle.p_logger, msg & " - Got AXI response "  & describe(got) & " expected " & describe(expected));
    end if;
  end;
end package body;
