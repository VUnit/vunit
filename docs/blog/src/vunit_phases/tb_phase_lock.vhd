-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.id_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.incrementer_pkg.all;
use work.event_pkg.all;

entity tb_phase_lock is
  generic(
    runner_cfg : string;
    test_runner_variant : positive;
    dut_checker_variant : positive;
    enable_end_of_simulation_process : boolean
  );
end entity;

architecture testbench of tb_phase_lock is
  signal clk : std_logic := '0';
  signal input_tvalid, output_tvalid, output_tvalid_i : std_logic := '0';
  signal input_tdata : std_logic_vector(15 downto 0);
  signal output_tdata : std_logic_vector(input_tdata'range);

  impure function load_data_from_file(data_set : integer) return integer_array_t is
  begin
    return load_csv(join(output_path(runner_cfg), "data" & integer'image(data_set) & ".csv"));
  end;

  procedure a_procedure_adding_some_delay is
  begin
    for iter in 1 to 10 loop
      wait for 0 ns;
    end loop;
  end;

  constant file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "log.txt"), use_color => true);
  constant log_handlers : log_handler_vec_t := (display_handler, file_handler);
  signal ctrl_arready : std_logic;
  signal ctrl_arvalid : std_logic;
  signal ctrl_araddr : std_logic_vector(7 downto 0);
  signal ctrl_rready : std_logic;
  signal ctrl_rvalid : std_logic;
  signal ctrl_rdata : std_logic_vector(31 downto 0);
  signal ctrl_rresp : std_logic_vector(1 downto 0);
  signal ctrl_awready : std_logic;
  signal ctrl_awvalid : std_logic;
  signal ctrl_awaddr : std_logic_vector(7 downto 0);
  signal ctrl_wready : std_logic;
  signal ctrl_wvalid : std_logic;
  signal ctrl_wdata : std_logic_vector(31 downto 0);
  signal ctrl_wstrb : std_logic_vector(3 downto 0);
  signal ctrl_bvalid : std_logic;
  signal ctrl_bready : std_logic;
  signal ctrl_bresp : std_logic_vector(1 downto 0);
begin
  process
  begin
    for idx in log_handlers'range loop
      hide_all(log_handlers(idx));
      show(log_handlers(idx), (info, warning, error, failure));
      show(dut_checker_logger, log_handlers(idx), trace);
      hide(get_logger("runner"), log_handlers(idx), info);
    end loop;
    set_log_handlers(root_logger, log_handlers);
    wait;
  end process;

  generate_test_runner : if test_runner_variant = 1 generate
  begin
    test_runner : process
      variable n_samples : integer;
      variable sample : integer;
      variable data_set : integer_array_t;

      procedure drive_dut(sample : integer) is
      begin
        input_tdata <= to_slv(sample, input_tdata'length);

        wait for rnd.RandTime(0 ns, 3 * clk_period, clk_period);

        input_tvalid <= '1';
        wait until rising_edge(clk);
        input_tvalid <= '0';
      end;
    begin
      test_runner_setup(runner, runner_cfg);

      for data_set_idx in 0 to n_data_sets - 1 loop
        data_set := load_data_from_file(data_set_idx);
        n_samples := length(data_set);
        push(queue, n_samples);
        notify(new_data_set);

        for sample_idx in 0 to n_samples - 1 loop
          sample := get(data_set, sample_idx);
          drive_dut(sample);
          push(queue, sample);
        end loop;
      end loop;

      -- start_snippet test_runner_with_event
      wait until is_active_msg(dut_checker_done);
      test_runner_cleanup(runner);
      -- end_snippet test_runner_with_event
    end process;

  elsif test_runner_variant = 2 generate
    test_runner : process
      variable n_samples : integer;
      variable sample : integer;
      variable data_set : integer_array_t;

      procedure drive_dut(sample : integer) is
      begin
        input_tdata <= to_slv(sample, input_tdata'length);

        wait for rnd.RandTime(0 ns, 3 * clk_period, clk_period);

        input_tvalid <= '1';
        wait until rising_edge(clk);
        input_tvalid <= '0';
      end;
    begin
      test_runner_setup(runner, runner_cfg);
      show(display_handler, trace);
      show(file_handler, trace);

      for data_set_idx in 0 to n_data_sets - 1 loop
        data_set := load_data_from_file(data_set_idx);
        n_samples := length(data_set);
        push(queue, n_samples);
        notify(new_data_set);

        for sample_idx in 0 to n_samples - 1 loop
          sample := get(data_set, sample_idx);
          drive_dut(sample);
          push(queue, sample);
        end loop;
      end loop;

      test_runner_cleanup(runner);
    end process;
  end generate;

  test_runner_watchdog(runner, 500 ns);

  generate_dut_checker : if dut_checker_variant = 1 generate
    -- start_snippet dut_checker_with_event
    dut_checker : process
    begin
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;

      for i in 1 to pop(queue) loop
        wait until (rising_edge(clk) and output_tvalid = '1') or log_active(vunit_error, decorate("while waiting on output data"), logger => dut_checker_logger);
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;

      if is_empty(queue) then
        notify(dut_checker_done);
      end if;
    end process;
  -- end_snippet dut_checker_with_event

  elsif dut_checker_variant = 2 generate
    -- start_snippet dut_checker_with_lock
    dut_checker : process
      constant key : key_t := get_entry_key(test_runner_cleanup);
    begin
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;
      lock(runner, key, dut_checker_logger);

      for i in 1 to pop(queue) loop
        wait until (rising_edge(clk) and output_tvalid = '1') or log_active(vunit_error, decorate("while waiting on output data"), logger => dut_checker_logger);
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;

      if is_empty(queue) then
        unlock(runner, key, dut_checker_logger);
      end if;
    end process;
  -- end_snippet dut_checker_with_lock

  elsif dut_checker_variant = 3 generate
    -- start_snippet dut_checker_with_initial_unlock
    dut_checker : process
      constant key : key_t := get_entry_key(test_runner_cleanup);
    begin
      if is_empty(queue) then
        unlock(runner, key, dut_checker_logger);
      end if;
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;
      lock(runner, key, dut_checker_logger);

      for i in 1 to pop(queue) loop
        wait until (rising_edge(clk) and output_tvalid = '1') or log_active(vunit_error, decorate("while waiting on output data"), logger => dut_checker_logger);
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;
    end process;
  -- end_snippet dut_checker_with_initial_unlock

  elsif dut_checker_variant = 4 generate
    -- start_snippet dut_checker_with_combined_if
    dut_checker : process
      constant key : key_t := get_entry_key(test_runner_cleanup);
    begin
      a_procedure_adding_some_delay;
      if is_empty(queue) then
        unlock(runner, key, dut_checker_logger);
        wait until is_active(new_data_set);
      end if;
      lock(runner, key, dut_checker_logger);

      for i in 1 to pop(queue) loop
        wait until (rising_edge(clk) and output_tvalid = '1') or log_active(vunit_error, decorate("while waiting on output data"), logger => dut_checker_logger);
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;
    end process;
    -- end_snippet dut_checker_with_combined_if
  end generate;

  generate_end_of_simulation_process: if enable_end_of_simulation_process generate
    constant axi_stream_checker_logger : logger_t := get_logger("axis_checker");
    constant eos_rule_logger : logger_t := get_logger("STREAM_ALL_DONE_EOS", parent => axi_stream_checker_logger);
    constant eos_rule_checker : checker_t := new_checker(eos_rule_logger);

    procedure check_stream_activity is
      constant num_of_active_streams : natural := 0;
    begin
      show(eos_rule_logger, display_handler, pass);
      show(eos_rule_logger, file_handler, pass);
      check_equal(eos_rule_checker, num_of_active_streams, 0, result("for number of active streams"));
    end;
  begin
    -- start_snippet end_of_simulation_process
    end_of_simulation_process : process
    begin
      wait until is_active(runner_phase) and is_within_gates_of(test_runner_cleanup);
      check_stream_activity;
      wait;
    end process;
    -- end_snippet end_of_simulation_process
  end generate;

  incrementer_inst : entity work.incrementer
    generic map(
      delay => 10,
      core_dump_on_vunit_error => false)
    port map(
      clk => clk,
      input_tdata => input_tdata,
      input_tvalid => input_tvalid,
      output_tdata => output_tdata,
      output_tvalid => output_tvalid,
      ctrl_arready => ctrl_arready,
      ctrl_arvalid => ctrl_arvalid,
      ctrl_araddr => ctrl_araddr,
      ctrl_rready => ctrl_rready,
      ctrl_rvalid => ctrl_rvalid,
      ctrl_rdata => ctrl_rdata,
      ctrl_rresp => ctrl_rresp,
      ctrl_awready => ctrl_awready,
      ctrl_awvalid => ctrl_awvalid,
      ctrl_awaddr => ctrl_awaddr,
      ctrl_wready => ctrl_wready,
      ctrl_wvalid => ctrl_wvalid,
      ctrl_wdata => ctrl_wdata,
      ctrl_wstrb => ctrl_wstrb,
      ctrl_bvalid => ctrl_bvalid,
      ctrl_bready => ctrl_bready,
      ctrl_bresp => ctrl_bresp);

  axi_lite_master_inst : entity vunit_lib.axi_lite_master
    generic map(
      bus_handle => ctrl_bus)
    port map(
      aclk => clk,
      arready => ctrl_arready,
      arvalid => ctrl_arvalid,
      araddr => ctrl_araddr,
      rready => ctrl_rready,
      rvalid => ctrl_rvalid,
      rdata => ctrl_rdata,
      rresp => ctrl_rresp,
      awready => ctrl_awready,
      awvalid => ctrl_awvalid,
      awaddr => ctrl_awaddr,
      wready => ctrl_wready,
      wvalid => ctrl_wvalid,
      wdata => ctrl_wdata,
      wstrb => ctrl_wstrb,
      bvalid => ctrl_bvalid,
      bready => ctrl_bready,
      bresp => ctrl_bresp);

  clk <= not clk after clk_period / 2;

end architecture;
