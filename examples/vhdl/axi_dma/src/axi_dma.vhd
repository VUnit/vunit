-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_pkg.all;
use work.axi_pkg.all;
use work.util_pkg.clog2;
use work.util_pkg.is_power_of_two;

entity axi_dma is
  generic (
    max_burst_length : natural range 0 to 256
    );
  port (
    clk : in std_logic;

    -- Control register bus
    axils_m2s : in axil_m2s_t;
    axils_s2m : out axil_s2m_t := axil_s2m_init;

    -- Read data bus
    axi_rd_m2s : out axi_rd_m2s_t := axi_rd_m2s_init;
    axi_rd_s2m : in axi_rd_s2m_t;

    -- Write data bus
    axi_wr_m2s : out axi_wr_m2s_t := axi_wr_m2s_init;
    axi_wr_s2m : in axi_wr_s2m_t
    );

end entity;

architecture a of axi_dma is
  constant bytes_per_beat : natural := axi_rd_s2m.r.data'length/8;
  constant c4kbyte : natural := 4096;

  signal start_transfer : std_logic;
  signal transfer_done  : std_logic := '0';
  signal src_address    : std_logic_vector(31 downto 0);
  signal dst_address    : std_logic_vector(31 downto 0);
  signal num_bytes      : std_logic_vector(31 downto 0);

  signal last_beat_written : boolean := false;

  constant max_num_burst_buffered : natural := 2;
  constant max_num_beats_buffered : natural := max_num_burst_buffered * max_burst_length;

  -- The maximum difference between two counters can only be
  -- max_num_beats_buffered + max_burst_length
  -- Thus it is enough to compare counters MOD max_num_beats_buffered
  -- We round up to nearest power of two to avoid non power of two MOD
  constant max_counter_value : natural := 2**clog2(max_num_beats_buffered + max_burst_length);

  signal num_beats_read : natural range 0 to max_counter_value-1;
  signal num_beats_written : natural range 0 to max_counter_value-1;

  constant max_outstanding_write_responses : natural := 7;
  signal outstanding_write_responses : natural;

begin

  ctrl_block : block
    type state_t is (idle, wait_for_transfer_done);
    signal state : state_t := idle;
  begin
    main : process
    begin
      wait until rising_edge(clk);


      case state is
        when idle =>
          if start_transfer = '1' then
            transfer_done <= '0';
            state <= wait_for_transfer_done;
          end if;

        when wait_for_transfer_done =>
          if last_beat_written and outstanding_write_responses = 0 then
            transfer_done <= '1';
            state <= idle;
          end if;
      end case;

    end process;
  end block;

  assert is_power_of_two(max_burst_length)
    report "max_burst_length shall be a power of two to generate efficient logic"
    severity failure;

  read_block : block
    type state_t is (wait_for_burst,
                     wait_for_space,
                     wait_for_accept);
    signal state : state_t := wait_for_burst;

    signal burst_valid : std_logic;
    signal burst_ready : std_logic := '0';
    signal burst_length : natural range 1 to max_burst_length;

    signal num_read_beats_ordered : natural range 0 to max_counter_value-1;
  begin

    axi_burst_gen_inst: entity work.axi_burst_gen
      generic map (
        max_burst_length => max_burst_length,
        bytes_per_beat   => bytes_per_beat)
      port map (
        clk          => clk,
        start        => start_transfer,
        start_addr   => src_address,
        num_bytes    => num_bytes,
        burst_valid  => burst_valid,
        burst_ready  => burst_ready,
        burst_addr   => axi_rd_m2s.ar.addr,
        burst_length => burst_length,
        burst_last   => open);

    main : process
    begin
      wait until rising_edge(clk);

      if start_transfer = '1' then
        num_read_beats_ordered <= 0;
      end if;

      case state is
        when wait_for_burst =>
          if burst_valid = '1' then
            num_read_beats_ordered <= (num_read_beats_ordered + burst_length) mod max_counter_value;
            state <= wait_for_space;
          end if;

        when wait_for_space =>
          if (num_read_beats_ordered - num_beats_written) mod max_counter_value < max_num_beats_buffered then
            axi_rd_m2s.ar.valid <= '1';
            state <= wait_for_accept;
          end if;

        when wait_for_accept =>
          if axi_rd_m2s.ar.valid = '1' and axi_rd_s2m.ar.ready = '1' then
            axi_rd_m2s.ar.valid <= '0';
            state <= wait_for_burst;
          end if;
      end case;
    end process;

    burst_ready <= axi_rd_m2s.ar.valid and axi_rd_s2m.ar.ready;
    axi_rd_m2s.ar.id <= (others => '0');
    axi_rd_m2s.ar.burst <= axi_burst_incr;
    axi_rd_m2s.ar.len <= std_logic_vector(to_unsigned(burst_length-1,
                                                      axi_rd_m2s.ar.len'length));
    axi_rd_m2s.ar.size <= std_logic_vector(to_unsigned(clog2(bytes_per_beat),
                                                       axi_rd_m2s.ar.size'length));

  end block;

  data_buffer : block
    type mem_t is array (natural range <>) of std_logic_vector(axi_rd_s2m.r.data'range);
    signal mem : mem_t(0 to max_num_beats_buffered - 1) := (others => (others => '0'));
  begin
    main : process
    begin
      wait until rising_edge(clk);

      if start_transfer = '1' then
        num_beats_read <= 0;
        num_beats_written <= 0;
      end if;

      if axi_rd_s2m.r.valid = '1' then
        mem(num_beats_read mod max_num_beats_buffered) <= axi_rd_s2m.r.data;
        num_beats_read <= (num_beats_read + 1) mod max_counter_value;
      end if;

      if axi_wr_m2s.w.valid = '1' and axi_wr_s2m.w.ready = '1' then
        num_beats_written <= (num_beats_written + 1) mod max_counter_value;
      end if;
    end process;

    axi_wr_m2s.w.data <= mem(num_beats_written mod max_num_beats_buffered);
    axi_wr_m2s.w.strb <= (others => '1');
    axi_rd_m2s.r.ready <= '1';
  end block;

  write_block : block
    type state_t is (wait_for_burst,
                     wait_for_read_data,
                     wait_for_accept);
    signal state : state_t := wait_for_burst;

    signal burst_valid : std_logic;
    signal burst_ready : std_logic := '0';
    signal burst_last : std_logic;
    signal burst_length : natural range 1 to max_burst_length;

    impure function next_outstanding_write_responses return natural is
      variable inc, dec : boolean;
    begin
      inc := axi_wr_m2s.aw.valid = '1' and axi_wr_s2m.aw.ready = '1';
      dec := axi_wr_s2m.b.valid = '1' and axi_wr_m2s.b.ready = '1';

      if inc and dec then
        return outstanding_write_responses;
      elsif inc then
        return outstanding_write_responses + 1;
      elsif dec then
        return outstanding_write_responses - 1;
      else
        return outstanding_write_responses;
      end if;
    end;

    signal num_write_beats_ordered : natural range 0 to max_counter_value-1;
    signal beat_count : natural range 1 to max_burst_length;
  begin

    main : process
    begin
      wait until rising_edge(clk);
      outstanding_write_responses <= next_outstanding_write_responses;

      burst_ready <= '0';

      if start_transfer = '1' then
        num_write_beats_ordered <= max_num_beats_buffered;
        outstanding_write_responses <= 0;
        last_beat_written <= false;
      end if;

      case state is
        when wait_for_burst =>
          if burst_valid = '1' and burst_ready = '0' then
            num_write_beats_ordered <= (num_write_beats_ordered + burst_length) mod max_counter_value;
            beat_count <= burst_length;
            state <= wait_for_read_data;
          end if;

        when wait_for_read_data =>
          if (num_beats_read - num_write_beats_ordered) mod max_counter_value >= max_num_beats_buffered then
            if outstanding_write_responses /= max_outstanding_write_responses then
              axi_wr_m2s.aw.valid <= '1';
              axi_wr_m2s.w.valid <= '1';
              state <= wait_for_accept;
            end if;
          end if;

        when wait_for_accept =>
          if axi_wr_m2s.aw.valid = '1' and axi_wr_s2m.aw.ready = '1' then
            axi_wr_m2s.aw.valid <= '0';
          end if;

          if axi_wr_m2s.w.valid = '1' and axi_wr_s2m.w.ready = '1' then
            if axi_wr_m2s.w.last = '1' then
              axi_wr_m2s.w.valid <= '0';
            else
              beat_count <= beat_count - 1;
            end if;
          end if;

          if axi_wr_m2s.aw.valid = '0' and axi_wr_m2s.w.valid = '0' then
            if burst_last = '1' then
              last_beat_written <= true;
            end if;
            burst_ready <= '1';
            state <= wait_for_burst;
          end if;

      end case;
    end process;

    axi_wr_m2s.w.last <= '1' when beat_count = 1 else '0';

    axi_burst_gen_inst: entity work.axi_burst_gen
      generic map (
        max_burst_length => max_burst_length,
        bytes_per_beat   => bytes_per_beat)
      port map (
        clk          => clk,
        start        => start_transfer,
        start_addr   => dst_address,
        num_bytes    => num_bytes,
        burst_valid  => burst_valid,
        burst_ready  => burst_ready,
        burst_addr   => axi_wr_m2s.aw.addr,
        burst_length => burst_length,
        burst_last   => burst_last);

    axi_wr_m2s.b.ready <= '1';

    axi_wr_m2s.aw.id <= (others => '0');
    axi_wr_m2s.aw.burst <= axi_burst_incr;
    axi_wr_m2s.aw.len <= std_logic_vector(to_unsigned(burst_length-1,
                                                      axi_wr_m2s.aw.len'length));
    axi_wr_m2s.aw.size <= std_logic_vector(to_unsigned(clog2(bytes_per_beat),
                                                       axi_wr_m2s.aw.size'length));

  end block;

  axi_dma_regs_inst: entity work.axi_dma_regs
    port map (
      clk            => clk,
      axils_m2s      => axils_m2s,
      axils_s2m      => axils_s2m,
      start_transfer => start_transfer,
      transfer_done  => transfer_done,
      src_address    => src_address,
      dst_address    => dst_address,
      num_bytes      => num_bytes);
end;
