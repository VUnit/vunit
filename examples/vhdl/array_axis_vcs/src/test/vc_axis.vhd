-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

entity vc_axis is
  generic (
    m_axis : axi_stream_master_t;
    s_axis : axi_stream_slave_t;
    data_width : natural := 32;
    fifo_depth : natural := 4
  );
  port (
    clk, rstn: in std_logic
  );
end entity;

architecture arch of vc_axis is

  signal m_valid, m_ready, m_last, s_valid, s_ready, s_last : std_logic;
  signal m_data, s_data : std_logic_vector(data_length(m_axis)-1 downto 0);

begin

  vunit_axism: entity vunit_lib.axi_stream_master
  generic map (
    master => m_axis
  )
  port map (
    aclk   => clk,
    tvalid => m_valid,
    tready => m_ready,
    tdata  => m_data,
    tlast  => m_last
  );

  vunit_axiss: entity vunit_lib.axi_stream_slave
  generic map (
    slave => s_axis
  )
  port map (
    aclk   => clk,
    tvalid => s_valid,
    tready => s_ready,
    tdata  => s_data,
    tlast  => s_last
  );

--

  uut: entity work.axis_buffer
  generic map (
    data_width => data_width,
    fifo_depth => fifo_depth
  )
  port map (
    s_axis_clk   => clk,
    s_axis_rstn  => rstn,
    s_axis_rdy   => m_ready,
    s_axis_data  => m_data,
    s_axis_valid => m_valid,
    s_axis_strb  => "1111",
    s_axis_last  => m_last,

    m_axis_clk   => clk,
    m_axis_rstn  => rstn,
    m_axis_valid => s_valid,
    m_axis_data  => s_data,
    m_axis_rdy   => s_ready,
    m_axis_strb  => open,
    m_axis_last  => s_last
  );

end architecture;
