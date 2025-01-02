-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.RandomPType;

entity tb_sobel_x is
  generic (
    runner_cfg : string;
    tb_path    : string
  );
end entity;

architecture tb of tb_sobel_x is

  signal clk           : std_logic := '0';
  signal input_tvalid  : std_logic := '0';
  signal input_tlast   : std_logic := '0';
  signal input_tdata   : unsigned(13 downto 0) := (others => '0');
  signal output_tvalid : std_logic;
  signal output_tlast  : std_logic;
  signal output_tdata  : signed(input_tdata'length downto 0);

  shared variable image, ref_image : integer_array_t;
  signal start, data_check_done, stimuli_done : boolean := false;

begin

  main : process
    impure function sobel_x (
      constant image : integer_array_t
    ) return integer_array_t is
      variable result: integer_array_t := new_2d(
        width     => width(image),
        height    => height(image),
        bit_width => bit_width(image)+1,
        is_signed => true
      );
    begin
      for y in 0 to height(image)-1 loop
        for x in 0 to width(image)-1 loop
          set(
            result,
            x => x,
            y => y,
            value => (
              get(image, minimum(x+1, width(image)-1),y)
              - get(image, maximum(x-1, 0), y)
            )
          );
        end loop;
      end loop;
    return result;
    end;

    variable rnd : RandomPType;

    impure function randomize (
      constant width, height, bit_width: natural
    ) return integer_array_t is
      variable image: integer_array_t := new_2d(
        width     => width,
        height    => height,
        bit_width => bit_width,
        is_signed => false
      );
    begin
      for idx in 0 to length(image)-1 loop
        set(image, idx, value => rnd.RandInt(lower_limit(image), upper_limit(image)));
      end loop;
      return image;
    end;

    procedure run_test is
    begin
      wait until rising_edge(clk);
      start <= true;
      wait until rising_edge(clk);
      start <= false;

      wait until (
        stimuli_done and
        data_check_done and
        rising_edge(clk)
      );
    end procedure;

    procedure test_random_image(width, height : natural) is
    begin
      image := randomize(width, height, input_tdata'length);
      ref_image := sobel_x(image);
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
        image := load_csv(tb_path & "input.csv");
        ref_image := load_csv(tb_path & "output.csv");
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

    report (
      "Sending image of size " &
      to_string(width(image)) & "x" &
      to_string(height(image))
    );

    for y in 0 to height(image)-1 loop
      for x in 0 to width(image)-1 loop
        wait until rising_edge(clk);
        input_tvalid <= '1';
        if x = width(image)-1 then
          input_tlast <= '1';
        else
          input_tlast <= '0';
        end if;
        input_tdata <= to_unsigned(get(image, x, y), input_tdata'length);
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
    for y in 0 to height(ref_image)-1 loop
      for x in 0 to width(ref_image)-1 loop
        wait until output_tvalid = '1' and rising_edge(clk);
        check_equal(output_tlast, x = width(ref_image)-1);
        check_equal(output_tdata, get(ref_image, x, y),
                    "x=" & to_string(x) & " y=" & to_string(y));
      end loop;
    end loop;
    report (
      "Done checking image of size " &
      to_string(width(ref_image)) & "x" &
      to_string(height(ref_image))
    );
    data_check_done <= true;
  end process;

  clk <= not clk after 1 ns;

  dut : entity work.sobel_x
    generic map (
      data_width => input_tdata'length
    )
    port map (
      clk           => clk,
      input_tvalid  => input_tvalid,
      input_tlast   => input_tlast,
      input_tdata   => input_tdata,
      output_tvalid => output_tvalid,
      output_tlast  => output_tlast,
      output_tdata  => output_tdata
    );

end architecture;
