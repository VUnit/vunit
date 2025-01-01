-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.string_ops.all;

entity tb_string_ops is
  generic (runner_cfg : string);
end entity tb_string_ops;

architecture test_fixture of tb_string_ops is
  procedure check (
    constant expr : in boolean;
    constant msg  : in string) is
  begin
    if not expr then
      assert false report msg severity failure;
    end if;
  end procedure check;
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
    constant hex_characters : string(1 to 16) := "0123456789abcdef";
    constant offset_string :string(10 to 16) := "foo bar";
    constant reverse_string :string(16 downto 10) := "foo bar";
    constant reversed_vector :unsigned(16 downto 4) := "1011010101001";
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("Test strip") then
        check(strip("") = "", "Strip of empty string should return an empty string. Got """ & strip("") & """.");
        check(strip(" a ") = "a", "Strip should remove spaces by default. Got """ & strip(" a ") & """.");
        check(strip(" ") = "", "Strip of single char string should return an empty string. Got """ & strip(" ") & """.");
        check(strip(" b") = "b", "Strip should handle left-sided strip. Got """ & strip(" b") & """.");
        check(strip("c ") = "c", "Strip should handle right-sided strip. Got """ & strip("c ") & """.");
        check(strip("d") = "d", "Strip should not affect strings without specified chars in the end/begining. Got """ & strip("d") & """.");
        check(strip(" e f ") = "e f", "Strip should not affect specified characters within the string. Got """ & strip(" e f ") & """.");
        check(strip("  g  ") = "g", "Strip should remove multiple instances of specified characters. Got """ & strip("  g  ") & """.");
        check(strip("-* h-*i-**-", "*-") = " h-*i", "Strip should remove multiple specified characters. Got """ & strip("-* h-*i-**-", "*-") & """.");
        check(strip(offset_string, "fo") = " bar", "Should handle offset strings. Got """ & strip(offset_string, "fo") & """.");
        check(strip(reverse_string, "fo") = " bar", "Should handle reversed strings. Got """ & strip(reverse_string, "fo") & """.");
      elsif run("Test rstrip") then
        check(rstrip("") = "", "rstrip of empty string should return an empty string. Got """ & rstrip("") & """.");
        check(rstrip(" a ") = " a", "rstrip should remove spaces by default. Got """ & rstrip(" a ") & """.");
        check(rstrip(" ") = "", "rstrip of single char string should return an empty string. Got """ & rstrip(" ") & """.");
        check(rstrip("d") = "d", "rstrip should not affect strings without specified chars in the end/begining. Got """ & rstrip("d") & """.");
        check(rstrip(" e f ") = " e f", "rstrip should not affect specified characters within the string. Got """ & rstrip(" e f ") & """.");
        check(rstrip("  g  ") = "  g", "rstrip should remove multiple instances of specified characters. Got """ & rstrip("  g  ") & """.");
        check(rstrip("-* h-*i-**-", "*-") = "-* h-*i", "rstrip should remove multiple specified characters. Got """ & rstrip("-* h-*i-**-", "*-") & """.");
        check(rstrip(offset_string, "rab") = "foo ", "Should handle offset strings. Got """ & rstrip(offset_string, "rab") & """.");
        check(rstrip(reverse_string, "rab") = "foo ", "Should handle reversed strings. Got """ & rstrip(reverse_string, "rab") & """.");

      elsif run("Test lstrip") then
        check(lstrip("") = "", "lstrip of empty string should return an empty string. Got """ & lstrip("") & """.");
        check(lstrip(" a ") = "a ", "lstrip should remove spaces by default. Got """ & lstrip(" a ") & """.");
        check(lstrip(" ") = "", "lstrip of single char string should return an empty string. Got """ & lstrip(" ") & """.");
        check(lstrip("d") = "d", "lstrip should not affect strings without specified chars in the end/begining. Got """ & lstrip("d") & """.");
        check(lstrip(" e f ") = "e f ", "lstrip should not affect specified characters within the string. Got """ & lstrip(" e f ") & """.");
        check(lstrip("  g  ") = "g  ", "lstrip should remove multiple instances of specified characters. Got """ & lstrip("  g  ") & """.");
        check(lstrip("-* h-*i-**-", "*-") = " h-*i-**-", "lstrip should remove multiple specified characters. Got """ & lstrip("-* h-*i-**-", "*-") & """.");
        check(lstrip(offset_string, "fo") = " bar", "Should handle offset strings. Got """ & lstrip(offset_string, "fo") & """.");
        check(lstrip(reverse_string, "fo") = " bar", "Should handle reversed strings. Got """ & lstrip(reverse_string, "fo") & """.");

      elsif run("Test count") then
        check(count("","a") = 0, "Empty string should return 0.");
        check(count(" a b ") = 3, "Should count spaces by default.");
        check(count(" a b ", "") = 6, "Should count an empty string between every character, at the beginning, and at the end.");
        check(count("", "") = 1, "Should return 1 when counting empty string in empty string");
        check(count("hello world or hello earth", "or") = 2, "Should handle multi-character substrings");
        check(count("hello world or hello earth", 'o') = 4, "Should handle character type inputs.");
        check(count("ababababa", "abab") = 2, "Should count non-overlapping occurences");
        check(count(offset_string, "o") = 2, "Should handle offset strings.");
        check(count(reverse_string, "o") = 2, "Should handle reversed strings.");
        check(count("ababababa", "a", 2 ,6) = 2, "Should handle parts of input string");
        check(count("aba", "a", 4 ,6) = 0, "Should not find anything outside of the string");
        check(count(offset_string, "a", 4 ,6) = 0, "Should not find anything outside of the string");
        check(count(reverse_string, "a", 12 ,4) = 0, "Should not find anything outside of the string");
        check(count("aba", "a", 3 ,1) = 0, "Should not find anything within a negative range");
        check(count("aba", "abab") = 0, "Should not find anything when substring is longer than the string");
      elsif run("Test find") then
        check(find("", "") = 1, "Empty string should be found at the start");
        check(find("foo bar", "") = 1, "Empty string should be found at the start");
		check(find("", "foo") = 0, "Nothing should be found in an empty string");
        check(find("foo bar", "foo") = 1, "Should find string at the start");
        check(find("foo bar", "bar") = 5, "Should find string at the end");
        check(find("foo bar", "o b") = 3, "Should find string in the middle");
        check(find("foo bar", "foo bar") = 1, "Should find full string");
        check(find("foo bar", 'f') = 1, "Should find character at the start");
        check(find("foo bar", 'r') = 7, "Should find character at the end");
        check(find("foo bar", ' ') = 4, "Should find character in the middle");
        check(find("foo bar", "bars") = 0, "Should return 0 when string not found");
        check(find("foo bar", "foo bars") = 0, "Should return 0 when string not found");
        check(find("foo bar", 'q') = 0, "Should return 0 when character not found");
        check(find(offset_string, "") = 10, "Empty string should be found at the start on offset string");
        check(find(offset_string, "foo") = 10, "Should find string at the start on offset string");
        check(find(offset_string, "bar") = 14, "Should find string at the end on offset string");
        check(find(offset_string, "o b") = 12, "Should find string in the middle on offset string");
        check(find(reverse_string, "") = 16, "Empty string should be found at the start on reversed string");
        check(find(reverse_string, "foo") = 16, "Should find string at the start on reversed string");
        check(find(reverse_string, "bar") = 12, "Should find string at the end on reversed string");
        check(find(reverse_string, "o b") = 14, "Should find string in the middle on reversed string");
        check(find("foo bar", "oo", 2, 6) = 2, "Should find string at the start of slice");
        check(find("foo bar", "ba", 2, 6) = 5, "Should find string at the end of slice");
        check(find("foo bar", "o b", 2, 6) = 3, "Should find string in the middle of slice");
        check(find("foo bar", "", 2, 6) = 2, "Empty string should be found at the start of slice");
        check(find("foo bar", 'f', 2, 6) = 0, "Should not find anything before slice");
        check(find("foo bar", "ar", 2, 6) = 0, "Should not find anything after slice");
        check(find(offset_string, 'f', 11, 15) = 0, "Should not find anything before slice in offset string");
        check(find(offset_string, "ar", 11, 15) = 0, "Should not find anything after slice in offset string");
        check(find(reverse_string, 'f', 15, 11) = 0, "Should not find anything before slice in reversed string");
        check(find(reverse_string, "ar", 15, 11) = 0, "Should not find anything after slice in reversed string");
        check(find("foo bar", "o b", 1, 100) = 3, "Should find in ranges wider than input'range");
        check(find("foo bar", "zen", 1, 100) = 0, "Should not find in ranges wider than input'range");
        check(find(offset_string, "o b", 1, 100) = 12, "Should find in ranges wider than input'range");
        check(find(offset_string, "zen", 1, 100) = 0, "Should not find in ranges wider than input'range");
        check(find(reverse_string, "o b", 100, 1) = 14, "Should find in ranges wider than input'range");
        check(find(reverse_string, "zen", 100, 1) = 0, "Should not find in ranges wider than input'range");
        check(find("foo bar", "o b", 3, 2) = 0, "Should not find string in negative range");
        check(find("foo bar", "o b", 30, 0) = 0, "Should not find string in negative range");
        check(find(reverse_string, "o b", 1, 100) = 0, "Should not find string in negative range");

      elsif run("Test image") then
        check(image("") = "", "Should return empty string on empty input vector.");
        check(image("UX01ZWLH-") = "UX01ZWLH-", "Should handle every possible bit value");
        ascending_vector := "UX01ZWLH-";
        check(image(ascending_vector) = "UX01ZWLH-", "Should handle ascending vector range");
        descending_vector := "UX01ZWLH-";
        check(image(descending_vector) = "UX01ZWLH-", "Should handle descending vector range");

      elsif run("Test hex_image") then
        check(hex_image("") = "x""""", "Should return empty hex string on empty input vector. Got " & hex_image("") & ".");
        check(hex_image("1010") = "x""a""", "Should handle zeros and ones.");
        check(hex_image("10101U10") = "x""aX""", "Should X out meta data groups.");
        check(hex_image("1010101") = "x""55""", "Should handle vectors without nibble-sized length.");
        ascending_vector := "10101U101";
        check(hex_image(ascending_vector) = "x""15X""", "Should handle ascending vector range");
        descending_vector := "10101U101";
        check(hex_image(descending_vector) = "x""15X""", "Should handle descending vector range");

      elsif run("Test from_hex") then
        for value in 0 to 15 loop
          check(from_hex((1 => hex_characters(value + 1))) = std_logic_vector(to_unsigned(value, 4)),
                "Should return """ & to_nibble_string(to_unsigned(value, 4)) & """ on from_hex(""" & hex_characters(value + 1) & """), got """ &
                to_nibble_string(from_hex((1 => hex_characters(value + 1)))) & """.");
        end loop;
        check(from_hex("ABCDEF") = "101010111100110111101111", "Should handle upper case letters");

      elsif run("Test replace") then
        check(replace("", 'a', 'b') = "", "Should return empty string on empty input string.");
        check(replace("foo bar", 'a', "") = "foo br", "Should be possible to replace segments with nothing");
        check(replace("foo bar ozon", 'o', 'b') = "fbb bar bzbn", "Should replace all specified characters by default.");
        check(replace("foo bar ozon", 'o', 'b', 2) = "fbb bar ozon", "Should replace first n specified characters if cnt is specified.");
        check(replace("foo bar ozon", 'o', 'b', 0) = "foo bar ozon", "Should not replace if cnt = 0.");
        check(replace("foo bar ozon", 'o', 'b', 10) = "fbb bar bzbn", "Should handle cnt > number of old characters.");
        check(replace("foo bar ozon", 'o', "ab") = "fabab bar abzabn", "Should be able to replace character with string.");
        check(replace("foo bar ozon", "oo", 'b') = "fb bar ozon", "Should be able to replace string with character.");
        check(replace("foo bar ozon", "oo", "ab") = "fab bar ozon", "Should be able to replace substring with another.");
        check(replace(offset_string, "oo", "ab") = "fab bar", "Should be able to replace offset string.");
        check(replace(reverse_string, "oo", "ab") = "fab bar", "Should be able to replace reversed string.");
        check(replace("cat anaconda cow", "anaconda", "snake") = "cat snake cow", "Should handle short uneffected endings.");

      elsif run("Test title") then
        check(title("") = "", "Should return empty string on empty input string.");
        check(title("foo bar 17!") = "Foo Bar 17!", "Should only capitalize the first letter of words.");
        check(title("Foo Bar") = "Foo Bar", "Should not affect already capitalized strings.");
        check(title("foo" & HT & "bar" & CR & "zoo") = "Foo" & HT & "Bar" & CR & "Zoo", "Should handle tab and return whitespaces.");
        check(title("foo    bar") = "Foo    Bar", "Should handle multiple whitespaces.");
        check(title(offset_string) = "Foo Bar", "Should handle offset strings.");
        check(title(reverse_string) = "Foo Bar", "Should handle reversed strings.");

      elsif run("Test upper") then
        check(upper("") = "", "Should return empty string on empty input string.");
        check(upper("foo bar 17!") = "FOO BAR 17!", "Should upper all letters of words.");
        check(upper("FOO BAR") = "FOO BAR", "Should not affect already upper strings.");
        check(upper("foo" & HT & "bar" & CR & "zoo") = "FOO" & HT & "BAR" & CR & "ZOO", "Should handle tab and return whitespaces.");
        check(upper(offset_string) = "FOO BAR", "Should handle offset strings.");
        check(upper(reverse_string) = "FOO BAR", "Should handle reversed strings.");

      elsif run("Test lower") then
        check(lower("") = "", "Should return empty string on empty input string.");
        check(lower("FOO BAR 17!") = "foo bar 17!", "Should lower all letters of words.");
        check(lower("foo bar") = "foo bar", "Should not affect already lower strings.");
        check(lower("FOO" & HT & "BAR" & CR & "ZOO") = "foo" & HT & "bar" & CR & "zoo", "Should handle tab and return whitespaces.");
        check(lower(offset_string) = "foo bar", "Should handle offset strings.");
        check(lower(reverse_string) = "foo bar", "Should handle reversed strings.");

      elsif run("Test split") then
        l := split("foo","");
        check(l'length = 5, "Should return 5 substrings when splitting ""foo""");
        check(l(0).all = "", "Should return """" as the first substring when splitting ""foo""");
        check(l(1).all = "f", "Should return ""f"" as the 1st substring when splitting ""foo""");
        check(l(2).all = "o", "Should return ""o"" as the 2nd substring when splitting ""foo""");
        check(l(3).all = "o", "Should return ""o"" as the 3rd substring when splitting ""foo""");
        check(l(4).all = "", "Should return """" as the 4th substring when splitting ""foo""");
        deallocate(l);

        l := split("","");
        check(l'length = 2, "Should return 2 substrings when splitting """"");
        check(l(0).all = "", "Should return """" as the first substring when splitting """"");
        check(l(1).all = "", "Should return """" as the 1st substring when splitting """"");
        deallocate(l);

        l := split("foo bar","q");
        check(l'length = 1, "Should return 1 substring when separator is missing");
        check(l(0).all = "foo bar", "Should return input string when separator is missing");
        deallocate(l);

        l := split("","q");
        check(l'length = 1, "Should return 1 substring when separator is missing");
        check(l(0).all = "", "Should return input string when separator is missing");
        deallocate(l);

        l := split("foo bar","b");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "foo ", "Should return ""foo "" as first substring when splitting ""foo bar"" with ""b""");
        check(l(1).all = "ar", "Should return ""ar"" as second substring when splitting ""foo bar"" with ""b""");
        deallocate(l);

        l := split("foo bar","o");
        check(l'length = 3, "Should return 3 substrings when separator appears twice.");
        check(l(0).all = "f", "Should return ""f"" as first substring when splitting ""foo bar"" with ""o""");
        check(l(1).all = "", "Should return """" as second substring when splitting ""foo bar"" with ""o""");
        check(l(2).all = " bar", "Should return "" bar"" as third substring when splitting ""foo bar"" with ""o""");
        deallocate(l);

        l := split("foo bar","f");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "", "Should return """" as first substring when splitting ""foo bar"" with ""f""");
        check(l(1).all = "oo bar", "Should return ""oo bar"" as second substring when splitting ""foo bar"" with ""f""");
        deallocate(l);

        l := split("foo bar","r");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "foo ba", "Should return ""foo ba"" as first substring when splitting ""foo bar"" with ""r""");
        check(l(1).all = "", "Should return """" as second substring when splitting ""foo bar"" with ""r""");
        deallocate(l);

        l := split("foo bar","foo");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "", "Should return """" as first substring when splitting ""foo bar"" with ""foo""");
        check(l(1).all = " bar", "Should return "" bar"" as second substring when splitting ""foo bar"" with ""foo""");
        deallocate(l);

        l := split("fooo bar","oo");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "f", "Should return ""f"" as first substring when splitting ""fooo bar"" with ""oo""");
        check(l(1).all = "o bar", "Should return ""o bar"" as second substring when splitting ""fooo bar"" with ""oo""");
        deallocate(l);

        l := split("foo bar","foo",0);
        check(l'length = 1, "Should return 1 substrings when max count is 0.");
        check(l(0).all = "foo bar", "Should return input when max count is zero.");
        deallocate(l);

        l := split("foo bar","o",1);
        check(l'length = 2, "Should return 2 substrings when max count is 1.");
        check(l(0).all = "f", "Should return ""f"" as first substring when splitting ""foo bar"" with ""o"" and max count = 1.");
        check(l(1).all = "o bar", "Should return ""o bar"" as second substring when splitting ""foo bar"" with ""o"" and max count = 1.");
        deallocate(l);

        l := split(offset_string,"b");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "foo ", "Should return ""foo "" as first substring when splitting ""foo bar"" with ""b""");
        check(l(1).all = "ar", "Should return ""ar"" as second substring when splitting ""foo bar"" with ""b""");
        deallocate(l);

        l := split(reverse_string,"b");
        check(l'length = 2, "Should return 2 substrings when separator appears once.");
        check(l(0).all = "foo ", "Should return ""foo "" as first substring when splitting ""foo bar"" with ""b""");
        check(l(1).all = "ar", "Should return ""ar"" as second substring when splitting ""foo bar"" with ""b""");
        deallocate(l);

      elsif run("Test to_integer_string") then
        check(to_integer_string(unsigned'("")) = "0", "Should return 0 on empty input");
        check(to_integer_string(unsigned'("0")) = natural'image(natural'low), "Should return correct value for minimum natural value.");
        check(to_integer_string(unsigned'(X"7fffffff")) = natural'image(2147483647), "Should return correct value for maximum natural value in 32-bit integer implementations.");
        check(to_integer_string(unsigned'(X"80000000")) = "2147483648", "Should return correct value for minimum natural above what's covered by 32-bit integer implementations.");
        check(to_integer_string(unsigned'(X"7b283d038f92b837d92f73a87380a")) = "39966790250241720040714860591790090", "Should handle really large values.");
        check(to_integer_string(unsigned'(X"00000000000000000000000000000")) = "0", "Should handle long zeros.");
        check(to_integer_string(unsigned'("00LL11HH")) = "15", "Should handle weak bits");
        check(to_integer_string(unsigned'("011110110010100000111101LLLL00111000HHHH1001001010111000001101111101100100101111011100111010100001110011100000001010")) = "39966790250241720040714860591790090", "Should handle really large values containing weak bits.");
        check(to_integer_string(unsigned'("1000000-")) = "NaN", "Should return NaN on vectors containing metalogical values");
        check(to_integer_string(unsigned'("1000000---000000000000000000000000000000000")) = "NaN", "Should return NaN on long vectors containing metalogical values");
        check(to_integer_string(unsigned'("1111101000")) = "1000", "Should return correct value for power of 10 values which are close to the maximum value that can be represented by the minimum binary vector for that value.");

        check(to_integer_string(std_logic_vector'("")) = "0", "Should return 0 on empty input");
        check(to_integer_string(std_logic_vector'("0")) = natural'image(natural'low), "Should return correct value for minimum natural value.");
        check(to_integer_string(std_logic_vector'(X"7fffffff")) = natural'image(2147483647), "Should return correct value for maximum natural value in 32-bit integer implementations.");
        check(to_integer_string(std_logic_vector'(X"80000000")) = "2147483648", "Should return correct value for minimum natural above what's covered by 32-bit integer implementations.");
        check(to_integer_string(std_logic_vector'(X"7b283d038f92b837d92f73a87380a")) = "39966790250241720040714860591790090", "Should handle really large values.");
        check(to_integer_string(std_logic_vector'(X"00000000000000000000000000000")) = "0", "Should handle long zeros.");
        check(to_integer_string(std_logic_vector'("00LL11HH")) = "15", "Should handle weak bits");
        check(to_integer_string(std_logic_vector'("011110110010100000111101LLLL00111000HHHH1001001010111000001101111101100100101111011100111010100001110011100000001010")) = "39966790250241720040714860591790090", "Should handle really large values containing weak bits.");
        check(to_integer_string(std_logic_vector'("1000000-")) = "NaN", "Should return NaN on vectors containing metalogical values");
        check(to_integer_string(std_logic_vector'("1000000---000000000000000000000000000000000")) = "NaN", "Should return NaN on long vectors containing metalogical values");


        check(to_integer_string(signed'("")) = "0", "Should return 0 on empty input");
        check(to_integer_string(signed'(X"80000000")) = integer'image(-2147483648), "Should return correct value for minimum value in 32-bit integer implementations.");
        check(to_integer_string(signed'(X"7fffffff")) = integer'image(2147483647), "Should return correct value for maximum value in 32-bit integer implementations.");
        check(to_integer_string(signed'("1" & X"7fffffff")) = "-2147483649", "Should return correct value for maximum integer below what's covered by 32-bit integer implementations.");
        check(to_integer_string(signed'(X"080000000")) = "2147483648", "Should return correct value for minimum integer above what's covered by 32-bit integer implementations.");
        check(to_integer_string(signed'(X"ab283d038f92b837d92f73a87380a")) = "-27533068910711039130181591688071158", "Should handle really small values.");
        check(to_integer_string(signed'(X"7b283d038f92b837d92f73a87380a")) = "39966790250241720040714860591790090", "Should handle really large values.");
        check(to_integer_string(signed'(X"00000000000000000000000000000")) = "0", "Should handle long zeros.");
        check(to_integer_string(signed'("00LL11HH")) = "15", "Should handle weak bits");
        check(to_integer_string(signed'("011110110010100000111101LLLL00111000HHHH1001001010111000001101111101100100101111011100111010100001110011100000001010")) = "39966790250241720040714860591790090", "Should handle really large values containing weak bits.");
        check(to_integer_string(signed'("1000000-")) = "NaN", "Should return NaN on vectors containing metalogical values");
        check(to_integer_string(signed'("1000000---000000000000000000000000000000000")) = "NaN", "Should return NaN on long vectors containing metalogical values");

      elsif run("Test to_nibble_string") then
        check(to_nibble_string(unsigned'("")) = "", "Should return empty string on empty input");
        check(to_nibble_string(std_logic_vector'("")) = "", "Should return empty string on empty input");
        check(to_nibble_string(signed'("")) = "", "Should return empty string on empty input");
        check(to_nibble_string(unsigned'("1")) = "1", "Should handle inputs shorter than a nibble");
        check(to_nibble_string(std_logic_vector'("1")) = "1", "Should handle inputs shorter than a nibble");
        check(to_nibble_string(signed'("1")) = "1", "Should handle inputs shorter than a nibble");
        check(to_nibble_string(unsigned'("1001")) = "1001", "Should handle single nibble");
        check(to_nibble_string(std_logic_vector'("1001")) = "1001", "Should handle single nibble");
        check(to_nibble_string(signed'("1001")) = "1001", "Should handle single nibble");
        check(to_nibble_string(unsigned'("011010101001")) = "0110_1010_1001", "Should handle an input value that is a multiple of nibbles");
        check(to_nibble_string(std_logic_vector'("011010101001")) = "0110_1010_1001", "Should handle an input value that is a multiple of nibbles");
        check(to_nibble_string(signed'("011010101001")) = "0110_1010_1001", "Should handle an input value that is a multiple of nibbles");
        check(to_nibble_string(unsigned'("1011010101001")) = "1_0110_1010_1001", "Should handle an input value that isn't a multiple of nibbles");
        check(to_nibble_string(std_logic_vector'("1011010101001")) = "1_0110_1010_1001", "Should handle an input value that isn't a multiple of nibbles");
        check(to_nibble_string(signed'("1011010101001")) = "1_0110_1010_1001", "Should handle an input value that isn't a multiple of nibbles");
        check(to_nibble_string(reversed_vector) = "1_0110_1010_1001", "Should handle reversed and offset input vectors");
        check(to_nibble_string(std_logic_vector(reversed_vector)) = "1_0110_1010_1001", "Should handle reversed and offset input vectors");
        check(to_nibble_string(signed(reversed_vector)) = "1_0110_1010_1001", "Should handle reversed and offset input vectors");
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
end test_fixture;
