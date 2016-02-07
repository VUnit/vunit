-- This package provides a dictionary types and operations
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ops.all;
use work.lang.all;
use work.log_types_pkg.all;
use work.check_pkg.all;
use std.textio.all;

package dictionary is
  subtype frozen_dictionary_t is string;
  constant empty_c : frozen_dictionary_t := "";

  function len (
    constant d : frozen_dictionary_t)
    return natural;
  impure function get (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return string;
  impure function has_key (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return boolean;

end package dictionary;

package body dictionary is
  function len (
    constant d : frozen_dictionary_t)
    return natural is
    variable key_value_pairs : lines_t;
  begin
    return count(replace(d, "::", "__escaped_colon__"), ":");
  end;

  type dictionary_status_t is (valid_value, key_error, corrupt_dictionary);

  procedure get (
    constant d     : in  frozen_dictionary_t;
    constant key   : in  string;
    variable value : inout line;
    variable status : out dictionary_status_t) is
    variable key_value_pairs, key_value_pair : lines_t;
  begin
    if value /= null then
      deallocate(value);
    end if;

    if len(d) = 0 then
      status := key_error;
      return;
    end if;

    key_value_pairs := split(replace(d, ",,", "__escaped_comma__"), ",");
    for i in key_value_pairs'range loop
      key_value_pair := split(replace(key_value_pairs(i).all, "::", "__escaped_colon__"), ":");
      if key_value_pair'length = 2 then
        if strip(replace(replace(key_value_pair(0).all, "__escaped_comma__", ','), "__escaped_colon__", ':')) = strip(key) then
          status := valid_value;
          write(value, strip(replace(replace(key_value_pair(1).all, "__escaped_comma__", ','), "__escaped_colon__", ':')));
          return;
        end if;
      else
        check(false, "Corrupt frozen dictionary item """ & key_value_pairs(i).all & """ in """ & d & """.", level => failure);
        write(value, string'("will return when log is mocked out during unit test."));
        return;
      end if;

    end loop;

    status := key_error;
    return;
  end procedure get;

  impure function get (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return string is
    variable value : line;
    variable status : dictionary_status_t;
  begin
    get(d, key, value, status);
    if status = valid_value then
      return value.all;
    else
      check(false, "Key error! """ & key & """ wasn't found in """ & d & """.", level => failure);
      return "will return when log is mocked out during unit test.";
    end if;

  end;

  impure function has_key (
    constant d   : frozen_dictionary_t;
    constant key : string)
    return boolean is
    variable value : line;
    variable status : dictionary_status_t;
  begin
    get(d, key, value, status);
    return status = valid_value;
  end;

end package body dictionary;
