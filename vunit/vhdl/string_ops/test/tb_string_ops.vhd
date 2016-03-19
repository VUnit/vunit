-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.string_ops.all;
use work.test_types.all;
use work.test_type_methods.all;

entity tb_string_ops is
  generic (runner_cfg : string);
end entity tb_string_ops;

architecture test_fixture of tb_string_ops is
  shared variable n_asserts : shared_natural;
  shared variable n_errors : shared_natural;

  procedure counting_assert (
    constant expr : in boolean;
    constant msg  : in string;
    constant level : in severity_level := error) is
  begin
    add(n_asserts, 1);
    if not expr then
      assert false report msg severity level;
      add(n_errors, 1);
    end if;
  end procedure counting_assert;
begin
  test_runner : process
    -- Override "=" to make it work in Vivado (doesn't consider two empty
    -- strings to be equal)
    function "=" (
      constant a : string;
      constant b : string)
      return boolean is

      function bool_to_sign (
        constant b : boolean)
        return integer is
      begin
        if b then
          return 1;
        else
          return -1;
        end if;
      end function bool_to_sign;

      variable ret_val : boolean := true;
    begin
      if a'length /= b'length then
        ret_val := false;
      else
        for i in 1 to a'length loop
          ret_val := a(a'left + bool_to_sign(a'ascending) * (i - 1)) =
                     b(b'left + bool_to_sign(b'ascending) * (i - 1));
          exit when not ret_val;
        end loop;
      end if;

      return ret_val;
    end function "=";
    variable ascending_vector : std_logic_vector(3 to 11);
    variable descending_vector : std_logic_vector(13 downto 5);
    variable l : lines_t;
    variable n_asserts_value, n_errors_value : integer;
    constant offset_string :string(10 to 16) := "foo bar";
    constant reverse_string :string(16 downto 10) := "foo bar";
    constant reversed_vector :unsigned(16 downto 4) := "1011010101001";
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test strip") then
        counting_assert(strip("") = "", "Strip of empty string should return an empty string. Got """ & strip("") & """.");
        counting_assert(strip(" a ") = "a", "Strip should remove spaces by default. Got """ & strip(" a ") & """.");
        counting_assert(strip(" ") = "", "Strip of single char string should return an empty string. Got """ & strip(" ") & """.");
        counting_assert(strip(" b") = "b", "Strip should handle left-sided strip. Got """ & strip(" b") & """.");
        counting_assert(strip("c ") = "c", "Strip should handle right-sided strip. Got """ & strip("c ") & """.");
        counting_assert(strip("d") = "d", "Strip should not affect strings without specified chars in the end/begining. Got """ & strip("d") & """.");
        counting_assert(strip(" e f ") = "e f", "Strip should not affect specified characters within the string. Got """ & strip(" e f ") & """.");
        counting_assert(strip("  g  ") = "g", "Strip should remove multiple instances of specified characters. Got """ & strip("  g  ") & """.");
        counting_assert(strip("-* h-*i-**-", "*-") = " h-*i", "Strip should remove multiple specified characters. Got """ & strip("-* h-*i-**-", "*-") & """.");
        counting_assert(strip(offset_string, "fo") = " bar", "Should handle offset strings. Got """ & strip(offset_string, "fo") & """.");
        counting_assert(strip(reverse_string, "fo") = " bar", "Should handle reversed strings. Got """ & strip(reverse_string, "fo") & """.");
      elsif run("Test rstrip") then
        counting_assert(rstrip("") = "", "rstrip of empty string should return an empty string. Got """ & rstrip("") & """.");
        counting_assert(rstrip(" a ") = " a", "rstrip should remove spaces by default. Got """ & rstrip(" a ") & """.");
        counting_assert(rstrip(" ") = "", "rstrip of single char string should return an empty string. Got """ & rstrip(" ") & """.");
        counting_assert(rstrip("d") = "d", "rstrip should not affect strings without specified chars in the end/begining. Got """ & rstrip("d") & """.");
        counting_assert(rstrip(" e f ") = " e f", "rstrip should not affect specified characters within the string. Got """ & rstrip(" e f ") & """.");
        counting_assert(rstrip("  g  ") = "  g", "rstrip should remove multiple instances of specified characters. Got """ & rstrip("  g  ") & """.");
        counting_assert(rstrip("-* h-*i-**-", "*-") = "-* h-*i", "rstrip should remove multiple specified characters. Got """ & rstrip("-* h-*i-**-", "*-") & """.");
        counting_assert(rstrip(offset_string, "rab") = "foo ", "Should handle offset strings. Got """ & rstrip(offset_string, "rab") & """.");
        counting_assert(rstrip(reverse_string, "rab") = "foo ", "Should handle reversed strings. Got """ & rstrip(reverse_string, "rab") & """.");

      elsif run("Test lstrip") then
        counting_assert(lstrip("") = "", "lstrip of empty string should return an empty string. Got """ & lstrip("") & """.");
        counting_assert(lstrip(" a ") = "a ", "lstrip should remove spaces by default. Got """ & lstrip(" a ") & """.");
        counting_assert(lstrip(" ") = "", "lstrip of single char string should return an empty string. Got """ & lstrip(" ") & """.");
        counting_assert(lstrip("d") = "d", "lstrip should not affect strings without specified chars in the end/begining. Got """ & lstrip("d") & """.");
        counting_assert(lstrip(" e f ") = "e f ", "lstrip should not affect specified characters within the string. Got """ & lstrip(" e f ") & """.");
        counting_assert(lstrip("  g  ") = "g  ", "lstrip should remove multiple instances of specified characters. Got """ & lstrip("  g  ") & """.");
        counting_assert(lstrip("-* h-*i-**-", "*-") = " h-*i-**-", "lstrip should remove multiple specified characters. Got """ & lstrip("-* h-*i-**-", "*-") & """.");
        counting_assert(lstrip(offset_string, "fo") = " bar", "Should handle offset strings. Got """ & lstrip(offset_string, "fo") & """.");
        counting_assert(lstrip(reverse_string, "fo") = " bar", "Should handle reversed strings. Got """ & lstrip(reverse_string, "fo") & """.");

      elsif run("Test count") then
        counting_assert(count("","a") = 0, "Empty string should return 0.");
        counting_assert(count(" a b ") = 3, "Should count spaces by default.");
        counting_assert(count(" a b ", "") = 6, "Should count an empty string between every character, at the beginning, and at the end.");
        counting_assert(count("", "") = 1, "Should return 1 when counting empty string in empty string");
        counting_assert(count("hello world or hello earth", "or") = 2, "Should handle multi-character substrings");
        counting_assert(count("hello world or hello earth", 'o') = 4, "Should handle character type inputs.");
        counting_assert(count("ababababa", "abab") = 2, "Should count non-overlapping occurences");
        counting_assert(count(offset_string, "o") = 2, "Should handle offset strings.");
        counting_assert(count(reverse_string, "o") = 2, "Should handle reversed strings.");
        counting_assert(count("ababababa", "a", 2 ,6) = 2, "Should handle parts of input string");
        counting_assert(count("aba", "a", 4 ,6) = 0, "Should not find anything outside of the string");
        counting_assert(count(offset_string, "a", 4 ,6) = 0, "Should not find anything outside of the string");
        counting_assert(count(reverse_string, "a", 12 ,4) = 0, "Should not find anything outside of the string");
        counting_assert(count("aba", "a", 3 ,1) = 0, "Should not find anything within a negative range");
        counting_assert(count("aba", "abab") = 0, "Should not find anything when substring is longer than the string");
      elsif run("Test find") then
        counting_assert(find("", "") = 1, "Empty string should be found at the start");
        counting_assert(find("foo bar", "") = 1, "Empty string should be found at the start");
        counting_assert(find("foo bar", "foo") = 1, "Should find string at the start");
        counting_assert(find("foo bar", "bar") = 5, "Should find string at the end");
        counting_assert(find("foo bar", "o b") = 3, "Should find string in the middle");
        counting_assert(find("foo bar", "foo bar") = 1, "Should find full string");
        counting_assert(find("foo bar", 'f') = 1, "Should find character at the start");
        counting_assert(find("foo bar", 'r') = 7, "Should find character at the end");
        counting_assert(find("foo bar", ' ') = 4, "Should find character in the middle");
        counting_assert(find("foo bar", "bars") = 0, "Should return 0 when string not found");
        counting_assert(find("foo bar", "foo bars") = 0, "Should return 0 when string not found");
        counting_assert(find("foo bar", 'q') = 0, "Should return 0 when character not found");
        counting_assert(find(offset_string, "") = 10, "Empty string should be found at the start on offset string");
        counting_assert(find(offset_string, "foo") = 10, "Should find string at the start on offset string");
        counting_assert(find(offset_string, "bar") = 14, "Should find string at the end on offset string");
        counting_assert(find(offset_string, "o b") = 12, "Should find string in the middle on offset string");
        counting_assert(find(reverse_string, "") = 16, "Empty string should be found at the start on reversed string");
        counting_assert(find(reverse_string, "foo") = 16, "Should find string at the start on reversed string");
        counting_assert(find(reverse_string, "bar") = 12, "Should find string at the end on reversed string");
        counting_assert(find(reverse_string, "o b") = 14, "Should find string in the middle on reversed string");
        counting_assert(find("foo bar", "oo", 2, 6) = 2, "Should find string at the start of slice");
        counting_assert(find("foo bar", "ba", 2, 6) = 5, "Should find string at the end of slice");
        counting_assert(find("foo bar", "o b", 2, 6) = 3, "Should find string in the middle of slice");
        counting_assert(find("foo bar", "", 2, 6) = 2, "Empty string should be found at the start of slice");
        counting_assert(find("foo bar", 'f', 2, 6) = 0, "Should not find anything before slice");
        counting_assert(find("foo bar", "ar", 2, 6) = 0, "Should not find anything after slice");
        counting_assert(find(offset_string, 'f', 11, 15) = 0, "Should not find anything before slice in offset string");
        counting_assert(find(offset_string, "ar", 11, 15) = 0, "Should not find anything after slice in offset string");
        counting_assert(find(reverse_string, 'f', 15, 11) = 0, "Should not find anything before slice in reversed string");
        counting_assert(find(reverse_string, "ar", 15, 11) = 0, "Should not find anything after slice in reversed string");
        counting_assert(find("foo bar", "o b", 1, 100) = 3, "Should find in ranges wider than input'range");
        counting_assert(find("foo bar", "zen", 1, 100) = 0, "Should not find in ranges wider than input'range");
        counting_assert(find(offset_string, "o b", 1, 100) = 12, "Should find in ranges wider than input'range");
        counting_assert(find(offset_string, "zen", 1, 100) = 0, "Should not find in ranges wider than input'range");
        counting_assert(find(reverse_string, "o b", 100, 1) = 14, "Should find in ranges wider than input'range");
        counting_assert(find(reverse_string, "zen", 100, 1) = 0, "Should not find in ranges wider than input'range");
        counting_assert(find("foo bar", "o b", 3, 2) = 0, "Should not find string in negative range");
        counting_assert(find("foo bar", "o b", 30, 0) = 0, "Should not find string in negative range");
        counting_assert(find(reverse_string, "o b", 1, 100) = 0, "Should not find string in negative range");

      elsif run("Test image") then
        counting_assert(image("") = "", "Should return empty string on empty input vector.");
        counting_assert(image("UX01ZWLH-") = "UX01ZWLH-", "Should handle every possible bit value");
        ascending_vector := "UX01ZWLH-";
        counting_assert(image(ascending_vector) = "UX01ZWLH-", "Should handle ascending vector range");
        descending_vector := "UX01ZWLH-";
        counting_assert(image(descending_vector) = "UX01ZWLH-", "Should handle descending vector range");

      elsif run("Test hex_image") then
        counting_assert(hex_image("") = "x""""", "Should return empty hex string on empty input vector. Got " & hex_image("") & ".");
        counting_assert(hex_image("1010") = "x""a""", "Should handle zeros and ones.");
        counting_assert(hex_image("10101U10") = "x""aX""", "Should X out meta data groups.");
        counting_assert(hex_image("1010101") = "x""55""", "Should handle vectors without nibble-sized length.");
        ascending_vector := "10101U101";
        counting_assert(hex_image(ascending_vector) = "x""15X""", "Should handle ascending vector range");
        descending_vector := "10101U101";
        counting_assert(hex_image(descending_vector) = "x""15X""", "Should handle descending vector range");

      elsif run("Test replace") then
        counting_assert(replace("", 'a', 'b') = "", "Should return empty string on empty input string.");
        counting_assert(replace("foo bar", 'a', "") = "foo br", "Should be possible to replace segments with nothing");
        counting_assert(replace("foo bar ozon", 'o', 'b') = "fbb bar bzbn", "Should replace all specified characters by default.");
        counting_assert(replace("foo bar ozon", 'o', 'b', 2) = "fbb bar ozon", "Should replace first n specified characters if cnt is specified.");
        counting_assert(replace("foo bar ozon", 'o', 'b', 0) = "foo bar ozon", "Should not replace if cnt = 0.");
        counting_assert(replace("foo bar ozon", 'o', 'b', 10) = "fbb bar bzbn", "Should handle cnt > number of old characters.");
        counting_assert(replace("foo bar ozon", 'o', "ab") = "fabab bar abzabn", "Should be able to replace character with string.");
        counting_assert(replace("foo bar ozon", "oo", 'b') = "fb bar ozon", "Should be able to replace string with character.");
        counting_assert(replace("foo bar ozon", "oo", "ab") = "fab bar ozon", "Should be able to replace substring with another.");
        counting_assert(replace(offset_string, "oo", "ab") = "fab bar", "Should be able to replace offset string.");
        counting_assert(replace(reverse_string, "oo", "ab") = "fab bar", "Should be able to replace reversed string.");
        counting_assert(replace("cat anaconda cow", "anaconda", "snake") = "cat snake cow", "Should handle short uneffected endings.");

      elsif run("Test title") then
        counting_assert(title("") = "", "Should return empty string on empty input string.");
        counting_assert(title("foo bar 17!") = "Foo Bar 17!", "Should only capitalize the first letter of words.");
        counting_assert(title("Foo Bar") = "Foo Bar", "Should not affect already capitalized strings.");
        counting_assert(title("foo" & HT & "bar" & CR & "zoo") = "Foo" & HT & "Bar" & CR & "Zoo", "Should handle tab and return whitespaces.");
        counting_assert(title("foo    bar") = "Foo    Bar", "Should handle multiple whitespaces.");
        counting_assert(title(offset_string) = "Foo Bar", "Should handle offset strings.");
        counting_assert(title(reverse_string) = "Foo Bar", "Should handle reversed strings.");

      elsif run("Test upper") then
        counting_assert(upper("") = "", "Should return empty string on empty input string.");
        counting_assert(upper("foo bar 17!") = "FOO BAR 17!", "Should upper all letters of words.");
        counting_assert(upper("FOO BAR") = "FOO BAR", "Should not affect already upper strings.");
        counting_assert(upper("foo" & HT & "bar" & CR & "zoo") = "FOO" & HT & "BAR" & CR & "ZOO", "Should handle tab and return whitespaces.");
        counting_assert(upper(offset_string) = "FOO BAR", "Should handle offset strings.");
        counting_assert(upper(reverse_string) = "FOO BAR", "Should handle reversed strings.");

      elsif run("Test lower") then
        counting_assert(lower("") = "", "Should return empty string on empty input string.");
        counting_assert(lower("FOO BAR 17!") = "foo bar 17!", "Should lower all letters of words.");
        counting_assert(lower("foo bar") = "foo bar", "Should not affect already lower strings.");
        counting_assert(lower("FOO" & HT & "BAR" & CR & "ZOO") = "foo" & HT & "bar" & CR & "zoo", "Should handle tab and return whitespaces.");
        counting_assert(lower(offset_string) = "foo bar", "Should handle offset strings.");
        counting_assert(lower(reverse_string) = "foo bar", "Should handle reversed strings.");

      elsif run("Test split") then
        l := split("foo","");
        counting_assert(l'length = 5, "Should return 5 substrings when splitting ""foo""");
        counting_assert(l(0).all = "", "Should return """" as the first substring when splitting ""foo""");
        counting_assert(l(1).all = "f", "Should return ""f"" as the 1st substring when splitting ""foo""");
        counting_assert(l(2).all = "o", "Should return ""o"" as the 2nd substring when splitting ""foo""");
        counting_assert(l(3).all = "o", "Should return ""o"" as the 3rd substring when splitting ""foo""");
        counting_assert(l(4).all = "", "Should return """" as the 4th substring when splitting ""foo""");
        deallocate(l);

        l := split("","");
        counting_assert(l'length = 2, "Should return 2 substrings when splitting """"");
        counting_assert(l(0).all = "", "Should return """" as the first substring when splitting """"");
        counting_assert(l(1).all = "", "Should return """" as the 1st substring when splitting """"");
        deallocate(l);

        l := split("foo bar","q");
        counting_assert(l'length = 1, "Should return 1 substring when separator is missing");
        counting_assert(l(0).all = "foo bar", "Should return input string when separator is missing");
        deallocate(l);

        l := split("","q");
        counting_assert(l'length = 1, "Should return 1 substring when separator is missing");
        counting_assert(l(0).all = "", "Should return input string when separator is missing");
        deallocate(l);

        l := split("foo bar","b");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "foo ", "Should return ""foo "" as first substring when splitting ""foo bar"" with ""b""");
        counting_assert(l(1).all = "ar", "Should return ""ar"" as second substring when splitting ""foo bar"" with ""b""");
        deallocate(l);

        l := split("foo bar","o");
        counting_assert(l'length = 3, "Should return 3 substrings when separator appears twice.");
        counting_assert(l(0).all = "f", "Should return ""f"" as first substring when splitting ""foo bar"" with ""o""");
        counting_assert(l(1).all = "", "Should return """" as second substring when splitting ""foo bar"" with ""o""");
        counting_assert(l(2).all = " bar", "Should return "" bar"" as third substring when splitting ""foo bar"" with ""o""");
        deallocate(l);

        l := split("foo bar","f");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "", "Should return """" as first substring when splitting ""foo bar"" with ""f""");
        counting_assert(l(1).all = "oo bar", "Should return ""oo bar"" as second substring when splitting ""foo bar"" with ""f""");
        deallocate(l);

        l := split("foo bar","r");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "foo ba", "Should return ""foo ba"" as first substring when splitting ""foo bar"" with ""r""");
        counting_assert(l(1).all = "", "Should return """" as second substring when splitting ""foo bar"" with ""r""");
        deallocate(l);

        l := split("foo bar","foo");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "", "Should return """" as first substring when splitting ""foo bar"" with ""foo""");
        counting_assert(l(1).all = " bar", "Should return "" bar"" as second substring when splitting ""foo bar"" with ""foo""");
        deallocate(l);

        l := split("fooo bar","oo");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "f", "Should return ""f"" as first substring when splitting ""fooo bar"" with ""oo""");
        counting_assert(l(1).all = "o bar", "Should return ""o bar"" as second substring when splitting ""fooo bar"" with ""oo""");
        deallocate(l);

        l := split("foo bar","foo",0);
        counting_assert(l'length = 1, "Should return 1 substrings when max count is 0.");
        counting_assert(l(0).all = "foo bar", "Should return input when max count is zero.");
        deallocate(l);

        l := split("foo bar","o",1);
        counting_assert(l'length = 2, "Should return 2 substrings when max count is 1.");
        counting_assert(l(0).all = "f", "Should return ""f"" as first substring when splitting ""foo bar"" with ""o"" and max count = 1.");
        counting_assert(l(1).all = "o bar", "Should return ""o bar"" as second substring when splitting ""foo bar"" with ""o"" and max count = 1.");
        deallocate(l);

        l := split(offset_string,"b");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "foo ", "Should return ""foo "" as first substring when splitting ""foo bar"" with ""b""");
        counting_assert(l(1).all = "ar", "Should return ""ar"" as second substring when splitting ""foo bar"" with ""b""");
        deallocate(l);

        l := split(reverse_string,"b");
        counting_assert(l'length = 2, "Should return 2 substrings when separator appears once.");
        counting_assert(l(0).all = "foo ", "Should return ""foo "" as first substring when splitting ""foo bar"" with ""b""");
        counting_assert(l(1).all = "ar", "Should return ""ar"" as second substring when splitting ""foo bar"" with ""b""");
        deallocate(l);

      elsif run("Test to_integer_string") then
        counting_assert(to_integer_string(unsigned'("")) = "0", "Should return 0 on empty input");
        counting_assert(to_integer_string(unsigned'("0")) = natural'image(natural'low), "Should return correct value for minimum natural value.");
        counting_assert(to_integer_string(unsigned'(X"7fffffff")) = natural'image(2147483647), "Should return correct value for maximum natural value in 32-bit integer implementations.");
        counting_assert(to_integer_string(unsigned'(X"80000000")) = "2147483648", "Should return correct value for minimum natural above what's covered by 32-bit integer implementations.");
        counting_assert(to_integer_string(unsigned'(X"7b283d038f92b837d92f73a87380a")) = "39966790250241720040714860591790090", "Should handle really large values.");
        counting_assert(to_integer_string(unsigned'(X"00000000000000000000000000000")) = "0", "Should handle long zeros.");
        counting_assert(to_integer_string(unsigned'("00LL11HH")) = "15", "Should handle weak bits");
        counting_assert(to_integer_string(unsigned'("011110110010100000111101LLLL00111000HHHH1001001010111000001101111101100100101111011100111010100001110011100000001010")) = "39966790250241720040714860591790090", "Should handle really large values containing weak bits.");
        counting_assert(to_integer_string(unsigned'("1000000-")) = "NaN", "Should return NaN on vectors containing metalogical values");
        counting_assert(to_integer_string(unsigned'("1000000---000000000000000000000000000000000")) = "NaN", "Should return NaN on long vectors containing metalogical values");
        counting_assert(to_integer_string(unsigned'("1111101000")) = "1000", "Should return correct value for power of 10 values which are close to the maximum value that can be represented by the minimum binary vector for that value.");

        counting_assert(to_integer_string(std_logic_vector'("")) = "0", "Should return 0 on empty input");
        counting_assert(to_integer_string(std_logic_vector'("0")) = natural'image(natural'low), "Should return correct value for minimum natural value.");
        counting_assert(to_integer_string(std_logic_vector'(X"7fffffff")) = natural'image(2147483647), "Should return correct value for maximum natural value in 32-bit integer implementations.");
        counting_assert(to_integer_string(std_logic_vector'(X"80000000")) = "2147483648", "Should return correct value for minimum natural above what's covered by 32-bit integer implementations.");
        counting_assert(to_integer_string(std_logic_vector'(X"7b283d038f92b837d92f73a87380a")) = "39966790250241720040714860591790090", "Should handle really large values.");
        counting_assert(to_integer_string(std_logic_vector'(X"00000000000000000000000000000")) = "0", "Should handle long zeros.");
        counting_assert(to_integer_string(std_logic_vector'("00LL11HH")) = "15", "Should handle weak bits");
        counting_assert(to_integer_string(std_logic_vector'("011110110010100000111101LLLL00111000HHHH1001001010111000001101111101100100101111011100111010100001110011100000001010")) = "39966790250241720040714860591790090", "Should handle really large values containing weak bits.");
        counting_assert(to_integer_string(std_logic_vector'("1000000-")) = "NaN", "Should return NaN on vectors containing metalogical values");
        counting_assert(to_integer_string(std_logic_vector'("1000000---000000000000000000000000000000000")) = "NaN", "Should return NaN on long vectors containing metalogical values");


        counting_assert(to_integer_string(signed'("")) = "0", "Should return 0 on empty input");
        counting_assert(to_integer_string(signed'(X"80000000")) = integer'image(-2147483648), "Should return correct value for minimum value in 32-bit integer implementations.");
        counting_assert(to_integer_string(signed'(X"7fffffff")) = integer'image(2147483647), "Should return correct value for maximum value in 32-bit integer implementations.");
        counting_assert(to_integer_string(signed'("1" & X"7fffffff")) = "-2147483649", "Should return correct value for maximum integer below what's covered by 32-bit integer implementations.");
        counting_assert(to_integer_string(signed'(X"080000000")) = "2147483648", "Should return correct value for minimum integer above what's covered by 32-bit integer implementations.");
        counting_assert(to_integer_string(signed'(X"ab283d038f92b837d92f73a87380a")) = "-27533068910711039130181591688071158", "Should handle really small values.");
        counting_assert(to_integer_string(signed'(X"7b283d038f92b837d92f73a87380a")) = "39966790250241720040714860591790090", "Should handle really large values.");
        counting_assert(to_integer_string(signed'(X"00000000000000000000000000000")) = "0", "Should handle long zeros.");
        counting_assert(to_integer_string(signed'("00LL11HH")) = "15", "Should handle weak bits");
        counting_assert(to_integer_string(signed'("011110110010100000111101LLLL00111000HHHH1001001010111000001101111101100100101111011100111010100001110011100000001010")) = "39966790250241720040714860591790090", "Should handle really large values containing weak bits.");
        counting_assert(to_integer_string(signed'("1000000-")) = "NaN", "Should return NaN on vectors containing metalogical values");
        counting_assert(to_integer_string(signed'("1000000---000000000000000000000000000000000")) = "NaN", "Should return NaN on long vectors containing metalogical values");

      elsif run("Test to_nibble_string") then
        counting_assert(to_nibble_string(unsigned'("")) = "", "Should return empty string on empty input");
        counting_assert(to_nibble_string(std_logic_vector'("")) = "", "Should return empty string on empty input");
        counting_assert(to_nibble_string(signed'("")) = "", "Should return empty string on empty input");
        counting_assert(to_nibble_string(unsigned'("1")) = "1", "Should handle inputs shorter than a nibble");
        counting_assert(to_nibble_string(std_logic_vector'("1")) = "1", "Should handle inputs shorter than a nibble");
        counting_assert(to_nibble_string(signed'("1")) = "1", "Should handle inputs shorter than a nibble");
        counting_assert(to_nibble_string(unsigned'("1001")) = "1001", "Should handle single nibble");
        counting_assert(to_nibble_string(std_logic_vector'("1001")) = "1001", "Should handle single nibble");
        counting_assert(to_nibble_string(signed'("1001")) = "1001", "Should handle single nibble");
        counting_assert(to_nibble_string(unsigned'("011010101001")) = "0110_1010_1001", "Should handle an input value that is a multiple of nibbles");
        counting_assert(to_nibble_string(std_logic_vector'("011010101001")) = "0110_1010_1001", "Should handle an input value that is a multiple of nibbles");
        counting_assert(to_nibble_string(signed'("011010101001")) = "0110_1010_1001", "Should handle an input value that is a multiple of nibbles");
        counting_assert(to_nibble_string(unsigned'("1011010101001")) = "1_0110_1010_1001", "Should handle an input value that isn't a multiple of nibbles");
        counting_assert(to_nibble_string(std_logic_vector'("1011010101001")) = "1_0110_1010_1001", "Should handle an input value that isn't a multiple of nibbles");
        counting_assert(to_nibble_string(signed'("1011010101001")) = "1_0110_1010_1001", "Should handle an input value that isn't a multiple of nibbles");
        counting_assert(to_nibble_string(reversed_vector) = "1_0110_1010_1001", "Should handle reversed and offset input vectors");
        counting_assert(to_nibble_string(std_logic_vector(reversed_vector)) = "1_0110_1010_1001", "Should handle reversed and offset input vectors");
        counting_assert(to_nibble_string(signed(reversed_vector)) = "1_0110_1010_1001", "Should handle reversed and offset input vectors");
      end if;
    end loop;

    get(n_asserts, n_asserts_value);
    get(n_errors, n_errors_value);
    write(output, "Number of assertions: " & natural'image(n_asserts_value) & LF);
    write(output, "Number of errors: " & natural'image(n_errors_value) & LF);
    test_runner_cleanup(runner);
    wait;
  end process;
end test_fixture;


-- vunit_pragma run_all_in_same_sim
