-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.array_pkg.all;


library osvvm;
use osvvm.RandomPkg.all;

entity tb_sobel_x is
  generic (
    runner_cfg : runner_cfg_t;
    output_path : string;
    tb_path : string);
end entity;

architecture tb of tb_sobel_x is
  signal clk : std_logic := '0';
  signal input_tvalid : std_logic := '0';
  signal input_tlast : std_logic := '0';
  signal input_tdata : unsigned(14-1 downto 0) := (others => '0');
  signal output_tvalid : std_logic;
  signal output_tlast : std_logic;
  signal output_tdata : signed(input_tdata'length downto 0);

  shared variable image : array_t;
  shared variable reference_image : array_t;
  signal start, data_check_done, stimuli_done : boolean := false;
begin

  main : process
    procedure sobel_x(variable image : inout array_t;
                      variable result : inout array_t) is
    begin
      result.init_2d(width => image.width,
                     height => image.height,
                     bit_width => image.bit_width+1,
                     is_signed => true);

      for y in 0 to image.height-1 loop
        for x in 0 to image.width-1 loop
          result.set(x => x, y => y,
                     value => (image.get(minimum(x+1, image.width-1),y) -
                               image.get(maximum(x-1, 0), y)));
        end loop;
      end loop;

    end procedure;

    variable rnd : RandomPType;

    procedure randomize(variable arr : inout array_t) is
    begin
      for idx in 0 to arr.length-1 loop
        arr.set(idx, value => rnd.RandInt(arr.lower_limit, arr.upper_limit));
      end loop;
    end procedure;

    procedure run_test is
    begin
      wait until rising_edge(clk);
      start <= true;
      wait until rising_edge(clk);
      start <= false;

      wait until (stimuli_done and
                  data_check_done and
                  rising_edge(clk));
    end procedure;

    procedure test_random_image(width, height : natural) is
    begin
      image.init_2d(width => width, height => height,
                    bit_width => input_tdata'length,
                    is_signed => false);
      randomize(image);
      sobel_x(image, result => reference_image);
      run_test;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);
    while test_suite loop
      if run("test_random_data_against_model") then
        test_random_image(128, 64);
        test_random_image(1, 13);
        test_random_image(16, 1);
        test_random_image(1, 1);
      elsif run("test_input_file_against_output_file") then
        image.load_csv(tb_path & "input.csv");
        reference_image.load_csv(tb_path & "output.csv");
        run_test;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

  stimuli_process : process
  begin
    wait until start and rising_edge(clk);
    stimuli_done <= false;

    report ("Sending image of size " &
            to_string(image.width) & "x" &
            to_string(image.height));

    for y in 0 to image.height-1 loop
      for x in 0 to image.width-1 loop
        wait until rising_edge(clk);
        input_tvalid <= '1';
        if x = image.width-1 then
          input_tlast <= '1';
        else
          input_tlast <= '0';
        end if;
        input_tdata <= to_unsigned(image.get(x,y), input_tdata'length);
      end loop;
    end loop;

    wait until rising_edge(clk);
    input_tvalid <= '0';

    stimuli_done <= true;
  end process;

  data_check_process : process
  begin
    wait until start and rising_edge(clk);
    data_check_done <= false;
    for y in 0 to reference_image.height-1 loop
      for x in 0 to reference_image.width-1 loop
        wait until output_tvalid = '1' and rising_edge(clk);
        check_equal(output_tlast, x = reference_image.width-1);
        check_equal(output_tdata, reference_image.get(x, y),
                    "x=" & to_string(x) & " y=" & to_string(y));
      end loop;
    end loop;
    report ("Done checking image of size " &
            to_string(reference_image.width) & "x" &
            to_string(reference_image.height));
    data_check_done <= true;
  end process;

  clk <= not clk after 1 ns;

  dut : entity work.sobel_x
    generic map (
      data_width => input_tdata'length)
    port map (
      clk           => clk,
      input_tvalid  => input_tvalid,
      input_tlast   => input_tlast,
      input_tdata   => input_tdata,
      output_tvalid => output_tvalid,
      output_tlast  => output_tlast,
      output_tdata  => output_tdata);

end architecture;
