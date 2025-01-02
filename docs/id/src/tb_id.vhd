-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

entity tb_dut is
  generic(
    runner_cfg : string;
    use_null_id : boolean := false);
end entity;

architecture vunit_style of tb_dut is
  constant raw_file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "raw_log.txt"), format => raw, use_color => false);
  constant verbose_file_handler : log_handler_t := new_log_handler(join(output_path(runner_cfg), "verbose_log.txt"), use_color => true);
  constant log_handlers : log_handler_vec_t := (display_handler, raw_file_handler, verbose_file_handler);
begin
  generate_vc_x : if use_null_id generate
    vc_x : entity work.verification_component_x_with_logger
      generic map(
        verbose_file_handler => verbose_file_handler
      );
  end generate;

  vc_x : process
  begin
    wait;
  end process;

  vc_y : process
  begin
    wait;
  end process;

  stimuli : process
    -- start_snippet id_from_attribute
    variable vc_x_id : id_t;
    -- start_folding
    variable vc_y_id : id_t;
    variable parent_id : id_t;
  begin
    for idx in log_handlers'range loop
      hide_all(log_handlers(idx));
      show(log_handlers(idx), (info, warning, error, failure));
      hide_all(get_logger("runner"), log_handlers(idx));
    end loop;
    set_log_handlers(root_logger, log_handlers);

    test_runner_setup(runner, runner_cfg);
    -- end_folding
    vc_x_id := get_id(vc_x'path_name);
    -- end_snippet id_from_attribute
    check_equal(full_name(vc_x_id), "tb_dut:vc_x");

    -- start_snippet id_from_string
    vc_x_id := get_id(":tb_dut:vc_x:");
    -- end_snippet id_from_string
    check_equal(full_name(vc_x_id), "tb_dut:vc_x");

    -- start_snippet id_from_string_wo_colon
    vc_x_id := get_id("tb_dut:vc_x");
    -- end_snippet id_from_string_wo_colon
    check_equal(full_name(vc_x_id), "tb_dut:vc_x");

    -- start_snippet second_id_from_string
    vc_y_id := get_id(vc_y'path_name); -- Creates an identity for vc_y but not for tb_dut.
    -- end_snippet second_id_from_string
    check_equal(full_name(vc_y_id), "tb_dut:vc_y");

    parent_id := get_parent(vc_x_id);
    -- start_snippet id_from_parent
    vc_y_id := get_id("vc_y", parent => parent_id);
    -- end_snippet id_from_parent
    check_equal(full_name(vc_y_id), "tb_dut:vc_y");

    while test_suite loop
      if run("Document naming") then
        --start_snippet id_naming
        print("Name = " & name(vc_x_id));
        print("Full name = " & full_name(vc_x_id));

        parent_id := get_parent(vc_x_id);
        print("Parent name = " & name(parent_id));
        --end_snippet id_naming
        info("Name = " & name(vc_x_id));
        info("Full name = " & full_name(vc_x_id));
        info("Parent name = " & name(parent_id));

      elsif run("Document get_tree") then
        -- start_snippet get_tree
        print("This is the tb_dut tree:" & get_tree(parent_id));
        -- end_snippet get_tree
        info("This is the tb_dut tree:" & get_tree(parent_id));

      elsif run("Document full tree") then
        info("This is the full identity tree:" & get_tree);

      elsif run("Document has_id") then
        info("has_id("""") = " & to_string(has_id("")));
        info("has_id(""tb_dut:vc_x"") = " & to_string(has_id("tb_dut:vc_x")));
        info("has_id(""vc_y"", parent => get_id(""tb_dut"")) = " & to_string(has_id("vc_y", parent => get_id("tb_dut"))));
        info("has_id(""vc_x"") = " & to_string(has_id("vc_x")));

      elsif run("Document traversing") then
        info("num_children(get_id(""tb_dut""))) = " & to_string(num_children(get_id("tb_dut"))));
        info("name(get_child(get_id(""tb_dut""), 1)) = " & name(get_child(get_id("tb_dut"), 1)));

      elsif run("Document null IDs") then
        wait for 20 ns;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

end architecture;
