-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.logger_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
context work.vunit_context;
context work.com_context;
context work.data_types_context;

package axi_stream_pkg is

  type axi_stream_master_t is record
    p_actor : actor_t;
    p_data_length : natural;
    p_id_length : natural;
    p_dest_length : natural;
    p_user_length : natural;
    p_logger : logger_t;
  end record;

  type axi_stream_slave_t is record
    p_actor : actor_t;
    p_data_length : natural;
    p_id_length : natural;
    p_dest_length : natural;
    p_user_length : natural;
    p_logger : logger_t;
  end record;

  constant axi_stream_logger : logger_t := get_logger("vunit_lib:axi_stream_pkg");
  impure function new_axi_stream_master(data_length : natural;
                                        id_length : natural := 0;
                                        dest_length : natural := 0;
                                        user_length : natural := 0;
                                        logger : logger_t := axi_stream_logger) return axi_stream_master_t;
  impure function new_axi_stream_slave(data_length : natural;
                                       id_length : natural := 0;
                                       dest_length : natural := 0;
                                       user_length : natural := 0;
                                       logger : logger_t := axi_stream_logger) return axi_stream_slave_t;
  impure function data_length(master : axi_stream_master_t) return natural;
  impure function data_length(master : axi_stream_slave_t) return natural;
  impure function id_length(master : axi_stream_master_t) return natural;
  impure function id_length(master : axi_stream_slave_t) return natural;
  impure function dest_length(master : axi_stream_master_t) return natural;
  impure function dest_length(master : axi_stream_slave_t) return natural;
  impure function user_length(master : axi_stream_master_t) return natural;
  impure function user_length(master : axi_stream_slave_t) return natural;
  impure function as_stream(master : axi_stream_master_t) return stream_master_t;
  impure function as_stream(slave : axi_stream_slave_t) return stream_slave_t;

  constant push_axi_stream_msg : msg_type_t := new_msg_type("push axi stream");
  constant pop_axi_stream_msg : msg_type_t := new_msg_type("pop axi stream");
  
  alias axi_stream_reference_t is msg_t;

  procedure push_axi_stream(signal net : inout network_t;
                            axi_stream : axi_stream_master_t;
                            tdata : std_logic_vector;
                            tlast : std_logic := '1';
                            tkeep : std_logic_vector := "";
                            tstrb : std_logic_vector := "";
                            tid : std_logic_vector := "";
                            tdest : std_logic_vector := "";
                            tuser : std_logic_vector := "");
                            
  -- Blocking: pop a value from the axi stream
  procedure pop_axi_stream(signal net : inout network_t;
                           stream : axi_stream_slave_t;
                           variable tdata : out std_logic_vector;
                           variable tlast : out std_logic;
                           variable tkeep : out std_logic_vector;
                           variable tstrb : out std_logic_vector;
                           variable tid : out std_logic_vector;
                           variable tdest : out std_logic_vector;
                           variable tuser : out std_logic_vector);

  -- Non-blocking: pop a value from the axi stream to be read in the future
  procedure pop_axi_stream(signal net : inout network_t;
                           stream : axi_stream_slave_t;
                           variable reference : inout axi_stream_reference_t);

  -- Blocking: Wait for reply to non-blocking pop
  procedure await_pop_axi_stream_reply(signal net : inout network_t;
                                       variable reference : inout axi_stream_reference_t;
                                       variable tdata : out std_logic_vector;
                                       variable tlast : out std_logic;
                                       variable tkeep : out std_logic_vector;
                                       variable tstrb : out std_logic_vector;
                                       variable tid : out std_logic_vector;
                                       variable tdest : out std_logic_vector;
                                       variable tuser : out std_logic_vector);

  -- Blocking: read axi stream and check result against expected value
  procedure check_stream(signal net : inout network_t;
                         stream : axi_stream_slave_t;
                         expected : std_logic_vector;
                         tlast : std_logic := '1';
                         tkeep : std_logic_vector := "";
                         tstrb : std_logic_vector := "";
                         tid : std_logic_vector := "";
                         tdest : std_logic_vector := "";
                         tuser : std_logic_vector := "";
                         msg : string := "");

end package;

package body axi_stream_pkg is

  impure function new_axi_stream_master(data_length : natural;
                                        id_length : natural := 0;
                                        dest_length : natural := 0;
                                        user_length : natural := 0;
                                        logger : logger_t := axi_stream_logger) return axi_stream_master_t is
  begin
    return (p_actor => new_actor,
            p_data_length => data_length,
            p_id_length => id_length,
            p_dest_length => dest_length,
            p_user_length => user_length,
            p_logger => logger);
  end;

  impure function new_axi_stream_slave(data_length : natural;
                                       id_length : natural := 0;
                                       dest_length : natural := 0;
                                       user_length : natural := 0;
                                       logger : logger_t := axi_stream_logger) return axi_stream_slave_t is
  begin
    return (p_actor => new_actor,
            p_data_length => data_length,
            p_id_length => id_length,
            p_dest_length => dest_length,
            p_user_length => user_length,
            p_logger => logger);
  end;

  impure function data_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_data_length;
  end;

  impure function data_length(master : axi_stream_slave_t) return natural is
  begin
    return master.p_data_length;
  end;

  impure function id_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_id_length;
  end;

  impure function id_length(master : axi_stream_slave_t) return natural is
  begin
    return master.p_id_length;
  end;

  impure function dest_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_dest_length;
  end;

  impure function dest_length(master : axi_stream_slave_t) return natural is
  begin
    return master.p_dest_length;
  end;

  impure function user_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_user_length;
  end;

  impure function user_length(master : axi_stream_slave_t) return natural is
  begin
    return master.p_user_length;
  end;

  impure function as_stream(master : axi_stream_master_t) return stream_master_t is
  begin
    return (p_actor => master.p_actor);
  end;

  impure function as_stream(slave : axi_stream_slave_t) return stream_slave_t is
  begin
    return (p_actor => slave.p_actor);
  end;

  procedure push_axi_stream(signal net : inout network_t;
                            axi_stream : axi_stream_master_t;
                            tdata : std_logic_vector;
                            tlast : std_logic := '1';
                            tkeep : std_logic_vector := "";
                            tstrb : std_logic_vector := "";
                            tid : std_logic_vector := "";
                            tdest : std_logic_vector := "";
                            tuser : std_logic_vector := "") is
    variable msg : msg_t := new_msg(push_axi_stream_msg);
    variable normalized_data : std_logic_vector(data_length(axi_stream)-1 downto 0) := (others => '0');
    variable normalized_keep : std_logic_vector(data_length(axi_stream)/8-1 downto 0) := (others => '0');
    variable normalized_strb : std_logic_vector(data_length(axi_stream)/8-1 downto 0) := (others => '0');
    variable normalized_id : std_logic_vector(id_length(axi_stream)-1 downto 0) := (others => '0');
    variable normalized_dest : std_logic_vector(dest_length(axi_stream)-1 downto 0) := (others => '0');
    variable normalized_user : std_logic_vector(user_length(axi_stream)-1 downto 0) := (others => '0');
  begin
    normalized_data(tdata'length-1 downto 0) := tdata;
    push_std_ulogic_vector(msg, normalized_data);
    push_std_ulogic(msg, tlast);
    normalized_keep(tkeep'length-1 downto 0) := tkeep;
    push_std_ulogic_vector(msg, normalized_keep);
    normalized_strb(tstrb'length-1 downto 0) := tstrb;  
    push_std_ulogic_vector(msg, normalized_strb);
    normalized_id(tid'length-1 downto 0) := tid; 
    push_std_ulogic_vector(msg, normalized_id);
    normalized_dest(tdest'length-1 downto 0) := tdest; 
    push_std_ulogic_vector(msg, normalized_dest);
    normalized_user(tuser'length-1 downto 0) := tuser; 
    push_std_ulogic_vector(msg, normalized_user);
    send(net, axi_stream.p_actor, msg);
  end;
  
  procedure pop_axi_stream(signal net : inout network_t;
                           stream : axi_stream_slave_t;
                           variable reference : inout axi_stream_reference_t) is
  begin
    reference := new_msg(pop_axi_stream_msg);
    send(net, stream.p_actor, reference);
  end;

  procedure await_pop_axi_stream_reply(signal net : inout network_t;
                                       variable reference : inout axi_stream_reference_t;
                                       variable tdata : out std_logic_vector;
                                       variable tlast : out std_logic;
                                       variable tkeep : out std_logic_vector;
                                       variable tstrb : out std_logic_vector;
                                       variable tid : out std_logic_vector;
                                       variable tdest : out std_logic_vector;
                                       variable tuser : out std_logic_vector) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    tdata := pop_std_ulogic_vector(reply_msg);
    tlast := pop_std_ulogic(reply_msg);
    tkeep := pop_std_ulogic_vector(reply_msg);
    tstrb := pop_std_ulogic_vector(reply_msg);
    tid := pop_std_ulogic_vector(reply_msg);
    tdest := pop_std_ulogic_vector(reply_msg);
    tuser := pop_std_ulogic_vector(reply_msg);
    delete(reference);
    delete(reply_msg);
  end;

  procedure pop_axi_stream(signal net : inout network_t;
                           stream : axi_stream_slave_t;
                           variable tdata : out std_logic_vector;
                           variable tlast : out std_logic;
                           variable tkeep : out std_logic_vector;
                           variable tstrb : out std_logic_vector;
                           variable tid : out std_logic_vector;
                           variable tdest : out std_logic_vector;
                           variable tuser : out std_logic_vector) is
    variable reference : axi_stream_reference_t;
  begin
    pop_axi_stream(net, stream, reference);
    await_pop_axi_stream_reply(net, reference, tdata, tlast, tkeep, tstrb, tid, tdest, tuser);
  end;

  procedure check_stream(signal net : inout network_t;
                         stream : axi_stream_slave_t;
                         expected : std_logic_vector;
                         tlast : std_logic := '1';
                         tkeep : std_logic_vector := "";
                         tstrb : std_logic_vector := "";
                         tid : std_logic_vector := "";
                         tdest : std_logic_vector := "";
                         tuser : std_logic_vector := "";
                         msg : string := "") is
    variable got_tdata : std_logic_vector(expected'range);
    variable got_tlast : std_logic;
    variable got_tkeep : std_logic_vector(tkeep'range);
    variable got_tstrb : std_logic_vector(tstrb'range);
    variable got_tid : std_logic_vector(tid'range);
    variable got_tdest : std_logic_vector(tdest'range);
    variable got_tuser : std_logic_vector(tuser'range);
  begin
    pop_axi_stream(net, stream, got_tdata, got_tlast, got_tkeep, got_tstrb, got_tid, got_tdest, got_tuser);
    check_equal(got_tdata, expected, msg);
    check_equal(got_tlast, tlast, msg);
    check_equal(got_tkeep, tkeep, msg);
    check_equal(got_tstrb, tstrb, msg);
    check_equal(got_tid, tid, msg);
    check_equal(got_tdest, tdest, msg);
    check_equal(got_tuser, tuser, msg);
  end procedure;

end package body;
