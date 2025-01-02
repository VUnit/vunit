-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.runner_pkg.all;
use vunit_lib.id_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

use work.event_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.incrementer_pkg.all;

entity tb_event is
  generic(
    runner_cfg : string;
    test_runner_variant : positive;
    dut_checker_variant : positive;
    inject_dut_bug : boolean := false;
    core_dump_on_vunit_error : boolean := false
  );
end entity;

architecture testbench of tb_event is
  signal clk : std_logic := '0';
  signal input_tvalid, output_tvalid, output_tvalid_i : std_logic := '0';
  signal input_tdata : std_logic_vector(15 downto 0);
  signal output_tdata : std_logic_vector(input_tdata'range);

  impure function load_data_from_file(data_set : integer) return integer_array_t is
  begin
    return load_csv(join(output_path(runner_cfg), "data" & integer'image(data_set) & ".csv"));
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
  generate_test_runner : if test_runner_variant = 1 generate
  begin
    test_runner : process
      -- Declarations
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

      -- start_snippet test_runner_process
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

      test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 500 ns);
  -- end_snippet test_runner_process

  elsif test_runner_variant = 2 generate
    test_runner : process
      -- Declarations
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
      for idx in log_handlers'range loop
        hide_all(log_handlers(idx));
        show(log_handlers(idx), (info, warning, error, failure));
      end loop;
      set_log_handlers(root_logger, log_handlers);

      test_runner_setup(runner, runner_cfg);
      if not inject_dut_bug then
        info("Identity hierarchy:" & get_tree(get_id("dut_checker")));
      end if;

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

      -- start_snippet wait_done_event
      wait until is_active_msg(dut_checker_done);
      test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 500 ns);
  -- end_snippet wait_done_event

  elsif test_runner_variant = 3 generate
    test_runner : process
      -- Declarations
      variable n_samples : integer;
      variable sample : integer;
      variable data_set : integer_array_t;
      variable status : std_logic_vector(data_length(ctrl_bus) - 1 downto 0);

      procedure drive_dut(sample : integer) is
      begin
        input_tdata <= to_slv(sample, input_tdata'length);

        wait for rnd.RandTime(0 ns, 3 * clk_period, clk_period);

        input_tvalid <= '1';
        wait until rising_edge(clk);
        input_tvalid <= '0';
      end;

      procedure read_register(addr : natural; data : out std_logic_vector) is
      begin
        read_bus(net, ctrl_bus, addr, data);
      end;
    begin
      for idx in log_handlers'range loop
        hide_all(log_handlers(idx));
        show(log_handlers(idx), (info, warning, error, failure));
      end loop;
      set_log_handlers(root_logger, log_handlers);

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

        -- start_snippet check_latency
        if data_set_idx = 0 then
          wait for max_latency;
          read_register(status_reg_addr, status);
          check_equal(status(n_samples_field), n_samples, result("for #processed samples"));
        end if;
        -- end_snippet check_latency

      end loop;

      wait until is_active_msg(dut_checker_done);
      test_runner_cleanup(runner);
    end process;

  elsif test_runner_variant = 4 generate
    test_runner : process
      -- Declarations
      variable n_samples : integer;
      variable sample : integer;
      variable data_set : integer_array_t;
      variable status : std_logic_vector(data_length(ctrl_bus) - 1 downto 0);

      procedure drive_dut(sample : integer) is
      begin
        input_tdata <= to_slv(sample, input_tdata'length);

        wait for rnd.RandTime(0 ns, 3 * clk_period, clk_period);

        input_tvalid <= '1';
        wait until rising_edge(clk);
        input_tvalid <= '0';
      end;

      procedure read_register(addr : natural; data : out std_logic_vector) is
      begin
        read_bus(net, ctrl_bus, addr, data);
      end;
    begin
      for idx in log_handlers'range loop
        hide_all(log_handlers(idx));
        show(log_handlers(idx), (info, warning, error, failure));
      end loop;
      set_log_handlers(root_logger, log_handlers);

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

        -- start_snippet notify_if_fail
        if data_set_idx = 0 then
          wait for max_latency;
          read_register(status_reg_addr, status);
          wait until rising_edge(clk);
          notify_if_fail(check_equal(status(n_samples_field), n_samples, result("for #processed samples")), vunit_error);
        end if;
        -- end_snippet notify_if_fail

      end loop;

      wait until is_active_msg(dut_checker_done);
      test_runner_cleanup(runner);
    end process;

  elsif test_runner_variant = 5 generate
    test_runner : process
      -- Declarations
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

      variable data : natural;
      constant expected_value : natural := 0;
    begin
      test_runner_setup(runner, runner_cfg);

      for data_set_idx in 0 to n_data_sets - 1 loop
        data_set := load_data_from_file(data_set_idx);
        n_samples := length(data_set);
        push(queue, n_samples);
        notify(new_data_set);

        for sample_idx in 0 to n_samples - 1 loop
          data := sample_idx;
          sample := get(data_set, sample_idx);
          drive_dut(sample);
          push(queue, sample);
          -- start_document(vunit_error)
          notify_if_fail(check_equal(data, expected_value), vunit_error);
          -- stop_document(vunit_error)
        end loop;
      end loop;

      wait until is_active_msg(dut_checker_done);
      test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 500 ns);
  end generate;

  -- TODO: Multiple driver example

  generate_dut_checker : if dut_checker_variant = 1 generate
  begin
    -- start_snippet dut_checker
    dut_checker : process
    begin
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;

      for i in 1 to pop(queue) loop
        wait until rising_edge(clk) and output_tvalid = '1';
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;
    end process;
  -- end_snippet dut_checker

  elsif dut_checker_variant = 2 generate
    -- start_snippet done_event
    dut_checker : process
    begin
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;

      for i in 1 to pop(queue) loop
        wait until rising_edge(clk) and output_tvalid = '1';
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;

      if is_empty(queue) then
        notify(dut_checker_done);
      end if;
    end process;
  -- end_snippet done_event

  elsif dut_checker_variant = 3 generate
    dut_checker : process
    begin
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;

      for i in 1 to pop(queue) loop
        -- start_snippet log_active
        wait until (rising_edge(clk) and output_tvalid = '1') or log_active(runner_timeout);
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
        -- end_snippet log_active
      end loop;

      if is_empty(queue) then
        notify(dut_checker_done);
      end if;
    end process;

    test_runner_watchdog(runner, 500 ns);

  elsif (dut_checker_variant = 4) or (dut_checker_variant = 5) or (dut_checker_variant = 6) generate
    dut_checker : process
      constant dut_checker_checker : checker_t := new_checker(dut_checker_logger);
    begin
      if is_empty(queue) then
        wait until is_active(new_data_set);
      end if;

      for i in 1 to pop(queue) loop
        case dut_checker_variant is
          when 4 =>
            -- start_snippet custom_logger
            wait until (rising_edge(clk) and output_tvalid = '1') or log_active(runner_timeout, logger => dut_checker_logger);
          -- end_snippet custom_logger
          when 5 =>
            -- start_snippet custom_message
            wait until (rising_edge(clk) and output_tvalid = '1') or log_active(runner_timeout, "Waiting on output data", logger => dut_checker_logger);
          -- end_snippet custom_message
          when others =>
            -- start_snippet decorated_message
            wait until (rising_edge(clk) and output_tvalid = '1') or log_active(runner_timeout, decorate("while waiting on output data"), logger => dut_checker_logger);
            -- end_snippet decorated_message
        end case;
        check_equal(dut_checker_checker, output_tdata, calculate_expected_output(pop(queue)));
      end loop;

      if is_empty(queue) then
        notify(dut_checker_done);
      end if;
    end process;

    test_runner_watchdog(runner, 500 ns);

  elsif dut_checker_variant = 7 generate
    dut_checker : process
    begin
      if is_empty(queue) then
        preprocess_this : wait until is_active(new_data_set);
      end if;

      for i in 1 to pop(queue) loop
        -- start_snippet vunit_error
        wait until (rising_edge(clk) and output_tvalid = '1') or log_active(vunit_error, decorate("while waiting on output data"), logger => dut_checker_logger);
        -- end_snippet vunit_error
        check_equal(output_tdata, calculate_expected_output(pop(queue)));
      end loop;

      if is_empty(queue) then
        notify(dut_checker_done);
      end if;
    end process;

    test_runner_watchdog(runner, 500 ns);
  end generate;

  incrementer_inst : entity work.incrementer
    generic map(
      delay => 10,
      core_dump_on_vunit_error => core_dump_on_vunit_error)
    port map(
      clk => clk,
      input_tdata => input_tdata,
      input_tvalid => input_tvalid,
      output_tdata => output_tdata,
      output_tvalid => output_tvalid_i,
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

  output_tvalid <= '0' when inject_dut_bug else output_tvalid_i;

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
