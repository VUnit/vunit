-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;

entity check_synthesis_test is
  port (
    clk : in  std_logic;
    d : in  std_logic;
    q : out std_logic);
end entity check_synthesis_test;

architecture synth of check_synthesis_test is
  signal en : std_logic := '1';
  signal std_false : std_logic := '0';
  signal std_true : std_logic := '1';
  signal unknown_vector : std_logic_vector(7 downto 0) := "0101X010";
  signal many_hot : std_logic_vector(7 downto 0) := "01011010";
begin
  checking: process (clk) is
    variable c : checker_t;
    variable pass : boolean;
    variable my_logger : logger_t;
    variable stat, stat2, stat3 : checker_stat_t;
    variable checker_cfg : checker_cfg_t;
    variable checker_cfg_export : checker_cfg_export_t;
    variable logger_cfg : logger_cfg_t;
    variable logger_cfg_export : logger_cfg_export_t;
  begin
    if rising_edge(clk) then
      q <= d;

      checker_init(default_src => "default_checker");

      checker_init(c, default_src => "custom_checker");

      checker_init(c, error, my_logger); -- Vivado crash when not explicitly
                                         -- assigning level

      checker_init(error, my_logger); -- Vivado crash when not explicitly
                                      -- assigning level

      check(c, false);
      check(c, pass, false);
      check(false);
      check(pass, false);

      get_checker_stat(stat);
      get_checker_stat(c, stat);

      reset_checker_stat;
      reset_checker_stat(c);

      get_checker_cfg(checker_cfg);
      get_checker_cfg(c, checker_cfg);

      get_checker_cfg(checker_cfg_export);
      get_checker_cfg(c, checker_cfg_export);

      get_logger_cfg(logger_cfg);
      get_logger_cfg(c, logger_cfg);

      get_logger_cfg(logger_cfg_export);
      get_logger_cfg(c, logger_cfg_export);

      checker_found_errors(pass);
      checker_found_errors(c, pass);

      stat3 := stat + stat2;

      check_true(c, false);
      check_true(c, pass, false);
      check_true(false);
      check_true(pass, false);
      pass := check_true(false);

      check_false(c, true);
      check_false(c, pass, true);
      check_false(true);
      check_false(pass, true);
      pass := check_false(true);

      check_implication(c, true, false);
      check_implication(c, pass, true, false);
      check_implication(true, false);
      check_implication(pass, true, false);
      pass := check_implication(true, false);

      check_not_unknown(c, pass, unknown_vector);
      check_not_unknown(c, unknown_vector);
      check_not_unknown(unknown_vector);
      check_not_unknown(pass, unknown_vector);
      pass := check_not_unknown(unknown_vector);

      check_zero_one_hot(c, pass, many_hot);
      check_zero_one_hot(pass, many_hot);
      check_zero_one_hot(c, many_hot);
      check_zero_one_hot(many_hot);
      pass := check_zero_one_hot(many_hot);

      check_one_hot(c, pass, many_hot);
      check_one_hot(pass, many_hot);
      check_one_hot(c, many_hot);
      check_one_hot(many_hot);
      pass := check_one_hot(many_hot);

      check_equal(unsigned'(X"A5"), unsigned'(X"5A"));
      check_equal(pass, unsigned'(X"A5"), unsigned'(X"5A"));
      pass := check_equal(unsigned'(X"A5"), unsigned'(X"5A"));
      check_equal(c, unsigned'(X"A5"), unsigned'(X"5A"));
      check_equal(c, pass, unsigned'(X"A5"), unsigned'(X"5A"));

      check_equal(unsigned'(X"A5"), natural'(90));
      check_equal(pass, unsigned'(X"A5"), natural'(90));
      pass := check_equal(unsigned'(X"A5"), natural'(90));
      check_equal(c, unsigned'(X"A5"), natural'(90));
      check_equal(c, pass, unsigned'(X"A5"), natural'(90));

      check_equal(natural'(165), unsigned'(X"5A"));
      check_equal(pass, natural'(165), unsigned'(X"5A"));
      pass := check_equal(natural'(165), unsigned'(X"5A"));
      check_equal(c, natural'(165), unsigned'(X"5A"));
      check_equal(c, pass, natural'(165), unsigned'(X"5A"));

      check_equal(natural'(165), natural'(90));
      check_equal(pass, natural'(165), natural'(90));
      pass := check_equal(natural'(165), natural'(90));
      check_equal(c, natural'(165), natural'(90));
      check_equal(c, pass, natural'(165), natural'(90));

      check_equal(unsigned'(X"A5"), std_logic_vector'(X"5A"));
      check_equal(pass, unsigned'(X"A5"), std_logic_vector'(X"5A"));
      pass := check_equal(unsigned'(X"A5"), std_logic_vector'(X"5A"));
      check_equal(c, unsigned'(X"A5"), std_logic_vector'(X"5A"));
      check_equal(c, pass, unsigned'(X"A5"), std_logic_vector'(X"5A"));

      check_equal(std_logic_vector'(X"A5"), unsigned'(X"5A"));
      check_equal(pass, std_logic_vector'(X"A5"), unsigned'(X"5A"));
      pass := check_equal(std_logic_vector'(X"A5"), unsigned'(X"5A"));
      check_equal(c, std_logic_vector'(X"A5"), unsigned'(X"5A"));
      check_equal(c, pass, std_logic_vector'(X"A5"), unsigned'(X"5A"));

      check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
      check_equal(pass, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
      pass := check_equal(std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
      check_equal(c, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
      check_equal(c, pass, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));

      check_equal(signed'(X"A5"), signed'(X"5A"));
      check_equal(pass, signed'(X"A5"), signed'(X"5A"));
      pass := check_equal(signed'(X"A5"), signed'(X"5A"));
      check_equal(c, signed'(X"A5"), signed'(X"5A"));
      check_equal(c, pass, signed'(X"A5"), signed'(X"5A"));

      check_equal(signed'(X"A5"), integer'(90));
      check_equal(pass, signed'(X"A5"), integer'(90));
      pass := check_equal(signed'(X"A5"), integer'(90));
      check_equal(c, signed'(X"A5"), integer'(90));
      check_equal(c, pass, signed'(X"A5"), integer'(90));

      check_equal(integer'(-91), signed'(X"5A"));
      check_equal(pass, integer'(-91), signed'(X"5A"));
      pass := check_equal(integer'(-91), signed'(X"5A"));
      check_equal(c, integer'(-91), signed'(X"5A"));
      check_equal(c, pass, integer'(-91), signed'(X"5A"));

      check_equal(integer'(-91), integer'(90));
      check_equal(pass, integer'(-91), integer'(90));
      pass := check_equal(integer'(-91), integer'(90));
      check_equal(c, integer'(-91), integer'(90));
      check_equal(c, pass, integer'(-91), integer'(90));

      check_equal('1', '0');
      check_equal(pass, '1', '0');
      pass := check_equal('1', '0');
      check_equal(c, '1', '0');
      check_equal(c, pass, '1', '0');

      check_equal('1', false);
      check_equal(pass, '1', false);
      pass := check_equal('1', false);
      check_equal(c, '1', false);
      check_equal(c, pass, '1', false);

      check_equal(true, '0');
      check_equal(pass, true, '0');
      pass := check_equal(true, '0');
      check_equal(c, true, '0');
      check_equal(c, pass, true, '0');

      check_equal(true, false);
      check_equal(pass, true, false);
      pass := check_equal(true, false);
      check_equal(c, true, false);
      check_equal(c, pass, true, false);
    end if;

    check_true(c, clk, en, std_false);
    check_true(clk, en, std_false);

    check_false(c, clk, en, std_true);
    check_false(clk, en, std_true);

    check_implication(c, clk, en, std_true, std_false);
    check_implication(clk, en, std_true, std_false);

    check_stable(c, clk, en, std_true, std_true, many_hot);
    check_stable(clk, en, std_true, std_true, many_hot);

    check_not_unknown(c, clk, en, unknown_vector);
    check_not_unknown(clk, en, unknown_vector);

    check_zero_one_hot(c, clk, en, many_hot);
    check_zero_one_hot(clk, en, many_hot);

    check_one_hot(c, clk, en, many_hot);
    check_one_hot(clk, en, many_hot);

    check_next(c, clk, en, std_true, std_false);
    check_next(clk, en, std_true, std_false);

    check_sequence(c, clk, en, many_hot);
    check_sequence(clk, en, many_hot);

  end process checking;
end architecture synth;


