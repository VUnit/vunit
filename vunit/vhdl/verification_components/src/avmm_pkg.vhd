-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Sebastiaan Jacobs basfriends@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
use vunit_lib.sync_pkg.all;
use vunit_lib.queue_pkg.all;

use work.stream_full_duplex_pkg.all;

package avmm_pkg
is
  type avmm_master_t is record
    p_actor: actor_t;
  end record;

  type avmm_slave_t is record
    p_actor: actor_t;
  end record;

  impure function new_avmm_master
    return avmm_master_t;
  impure function new_avmm_slave
    return avmm_slave_t;

  impure function as_stream
  (
    avmm_master: avmm_master_t
  ) return stream_full_duplex_t;
  impure function as_stream
  (
    avmm_slave: avmm_slave_t
  ) return stream_full_duplex_t;

  impure function as_sync
  (
    avmm_master: avmm_master_t
  ) return sync_handle_t;
  impure function as_sync
  (
    avmm_slave: avmm_slave_t
  ) return sync_handle_t;

  constant avmm_m2s_data_msg: msg_type_t := new_msg_type("AVMM M2S Transaction");
  constant avmm_s2m_data_msg: msg_type_t := new_msg_type("AVMM S2M Transaction");

  procedure push_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    constant read: in std_logic;
    constant write: in std_logic;
    constant address: in integer;
    constant writedata: in std_logic_vector;
    constant last: in boolean := false
  );

  procedure push_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    constant readdata: in std_logic_vector;
    constant last: in boolean := false
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable read: out std_logic;
    variable write: out std_logic;
    variable address: out integer;
    variable writedata: out std_logic_vector;
    variable last: out boolean
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable read: out std_logic;
    variable write: out std_logic;
    variable address: out integer;
    variable writedata: out std_logic_vector
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable readdata: out std_logic_vector
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable readdata: out std_logic_vector;
    variable last: out boolean
  );

  procedure check_avmm_s2m_msg
  (
    signal net: inout network_t;
    constant master_avmm: in avmm_master_t;
    constant ref_msg: in msg_t
  );

  procedure check_avmm_s2m_msg
  (
    signal net: inout network_t;
    constant master_avmm: in avmm_master_t;
    constant ref_readdata: in std_logic_vector
  );

  procedure check_avmm_m2s_msg
  (
    signal net: inout network_t;
    constant slave_avmm: in avmm_slave_t;
    constant ref_msg: in msg_t
  );

  procedure check_avmm_m2s_msg
  (
    signal net: inout network_t;
    constant slave_avmm: in avmm_slave_t;
    constant ref_read: in std_logic;
    constant ref_write: in std_logic;
    constant ref_address: in integer;
    constant ref_writedata: in std_logic_vector
  );

  procedure nudge
  (
    signal irq: out std_logic
  );
end package;

package body avmm_pkg
is

  impure function new_avmm_master
    return avmm_master_t
  is
  begin
    return
    (
      p_actor => new_actor
    );
  end;

  impure function new_avmm_slave
    return avmm_slave_t
  is
  begin
    return
    (
      p_actor => new_actor
    );
  end;

  impure function as_stream
  (
    avmm_master: avmm_master_t
  ) return stream_full_duplex_t
  is
  begin
    return stream_full_duplex_t'(p_actor => avmm_master.p_actor);
  end;

  impure function as_stream
  (
    avmm_slave: avmm_slave_t
  ) return stream_full_duplex_t
  is
  begin
    return stream_full_duplex_t'(p_actor => avmm_slave.p_actor);
  end;

  impure function as_sync
  (
    avmm_master: avmm_master_t
  ) return sync_handle_t
  is
  begin
    return avmm_master.p_actor;
  end;

  impure function as_sync
  (
    avmm_slave: avmm_slave_t
  ) return sync_handle_t
  is
  begin
    return avmm_slave.p_actor;
  end;

  procedure push_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    constant read: in std_logic;
    constant write: in std_logic;
    constant address: in integer;
    constant writedata: in std_logic_vector;
    constant last: in boolean := false
  )
  is
    variable m2s_msg: msg_t := new_msg(stream_push_msg);
  begin
    push_std_ulogic(m2s_msg, read);
    push_std_ulogic(m2s_msg, write);
    push_integer(m2s_msg, address);
    push_std_ulogic_vector(m2s_msg, writedata);
    push_boolean(m2s_msg, last);
    send(net, stream.p_actor, m2s_msg);
  end procedure push_stream;

  procedure push_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    constant readdata: in std_logic_vector;
    constant last: in boolean := false
  )
  is
    variable m2s_msg: msg_t := new_msg(stream_push_msg);
  begin
    push_std_ulogic_vector(m2s_msg, readdata);
    push_boolean(m2s_msg, last);
    send(net, stream.p_actor, m2s_msg);
  end procedure push_stream;

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable read: out std_logic;
    variable write: out std_logic;
    variable address: out integer;
    variable writedata: out std_logic_vector;
    variable last: out boolean
  )
  is
    variable reference: stream_reference_t;
    variable m2s_msg: msg_t;
  begin
    reference := new_msg(stream_pop_msg);
    send(net, stream.p_actor, reference);

    receive_reply(net, reference, m2s_msg);

    read := pop_std_ulogic(m2s_msg);
    write := pop_std_ulogic(m2s_msg);
    address := pop_integer(m2s_msg);
    writedata := pop_std_ulogic_vector(m2s_msg);
    last := pop_boolean(m2s_msg);

    delete(reference);
    delete(m2s_msg);
  end procedure pop_stream;

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable read: out std_logic;
    variable write: out std_logic;
    variable address: out integer;
    variable writedata: out std_logic_vector
  )
  is
    variable reference: stream_reference_t;
    variable m2s_msg: msg_t;
  begin
    reference := new_msg(stream_pop_msg);
    send(net, stream.p_actor, reference);

    receive_reply(net, reference, m2s_msg);

    read := pop_std_ulogic(m2s_msg);
    write := pop_std_ulogic(m2s_msg);
    address := pop_integer(m2s_msg);
    writedata := pop_std_ulogic_vector(m2s_msg);

    delete(reference);
    delete(m2s_msg);
  end procedure pop_stream;

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable readdata: out std_logic_vector;
    variable last: out boolean
  )
  is
    variable reference: stream_reference_t;
    variable m2s_msg: msg_t;
  begin
    reference := new_msg(stream_pop_msg);
    send(net, stream.p_actor, reference);

    receive_reply(net, reference, m2s_msg);

    readdata := pop_std_ulogic_vector(m2s_msg);
    last := pop_boolean(m2s_msg);

    delete(reference);
    delete(m2s_msg);
  end procedure pop_stream;

  procedure pop_stream
  (
    signal net: inout network_t;
    constant stream: in stream_full_duplex_t;
    variable readdata: out std_logic_vector
  )
  is
    variable reference: stream_reference_t;
    variable m2s_msg: msg_t;
  begin
    reference := new_msg(stream_pop_msg);
    send(net, stream.p_actor, reference);

    receive_reply(net, reference, m2s_msg);

    readdata := pop_std_ulogic_vector(m2s_msg);

    delete(reference);
    delete(m2s_msg);
  end procedure pop_stream;

  procedure check_avmm_m2s_msg
  (
    signal net: inout network_t;
    constant slave_avmm: in avmm_slave_t;
    constant ref_msg: in msg_t
  )
  is
    variable ref_read: std_logic;
    variable ref_write: std_logic;
    variable ref_address: integer;
    variable ref_writedata: std_logic_vector(31 downto 0);
  begin

    ref_read := pop_std_ulogic(ref_msg);
    ref_write := pop_std_ulogic(ref_msg);
    ref_address := pop_integer(ref_msg);
    ref_writedata := pop_std_ulogic_vector(ref_msg);

    check_avmm_m2s_msg
    (
      net => net,
      slave_avmm => slave_avmm,
      ref_read => ref_read,
      ref_write => ref_write,
      ref_address => ref_address,
      ref_writedata => ref_writedata
    );
  end procedure check_avmm_m2s_msg;

  procedure check_avmm_m2s_msg
  (
    signal net: inout network_t;
    constant slave_avmm: in avmm_slave_t;
    constant ref_read: in std_logic;
    constant ref_write: in std_logic;
    constant ref_address: in integer;
    constant ref_writedata: in std_logic_vector
  )
  is
    variable reference: stream_reference_t;
    variable reply_msg: msg_t;
    variable dut_read: std_logic;
    variable dut_write: std_logic;
    variable dut_address: integer;
    variable dut_writedata: std_logic_vector(31 downto 0);
  begin
    reference := new_msg(stream_pop_msg);
    send(net, slave_avmm.p_actor, reference);
    receive_reply(net, reference, reply_msg);

    dut_read := pop_std_ulogic(reply_msg);
    dut_write := pop_std_ulogic(reply_msg);
    dut_address := pop_integer(reply_msg);
    dut_writedata := pop_std_ulogic_vector(reply_msg);

    check_equal(dut_read, ref_read, "Check M2S read");
    check_equal(dut_write, ref_write, "Check M2S write");
    check_equal(dut_address, ref_address, "Check M2S address");
    check_equal(dut_writedata, ref_writedata, "Check M2S writedata");

    delete(reference);
    delete(reply_msg);
  end procedure check_avmm_m2s_msg;

  procedure check_avmm_s2m_msg
  (
    signal net: inout network_t;
    constant master_avmm: in avmm_master_t;
    constant ref_msg: in msg_t
  )
  is
    variable ref_readdata: std_logic_vector(31 downto 0);
  begin
    ref_readdata := pop_std_ulogic_vector(ref_msg);

    check_avmm_s2m_msg
    (
      net => net,
      master_avmm => master_avmm,
      ref_readdata => ref_readdata
    );
  end procedure check_avmm_s2m_msg;  

  procedure check_avmm_s2m_msg
  (
    signal net: inout network_t;
    constant master_avmm: in avmm_master_t;
    constant ref_readdata: in std_logic_vector
  )
  is
    variable reference: stream_reference_t;
    variable reply_msg: msg_t;
    variable dut_readdata: std_logic_vector(31 downto 0);
  begin
    reference := new_msg(stream_pop_msg);
    send(net, master_avmm.p_actor, reference);
    receive_reply(net, reference, reply_msg);

    dut_readdata := pop_std_ulogic_vector(reply_msg);

    check_equal(dut_readdata, ref_readdata, "Check S2M readdata");

    delete(reference);
    delete(reply_msg);
  end procedure check_avmm_s2m_msg;

  procedure nudge
  (
    signal irq: out std_logic
  )
  is
  begin
    irq <= '1';
    wait for 0 ns;
    irq <= '0';
    wait for 0 ns;
  end procedure nudge;
end package body;