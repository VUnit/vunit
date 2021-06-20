-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.logger_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;

package id_pkg is
  constant id_logger : logger_t := get_logger("vunit_lib:id_pkg");
  constant id_checker : checker_t := new_checker(id_logger);

  type id_t is record
    p_data : integer_vector_ptr_t;
  end record id_t;

  constant null_id : id_t := (p_data => null_integer_vector_ptr);

  type id_vec_t is array (integer range <>) of id_t;

  impure function new_id(name : string := "") return id_t;
  impure function name(id : id_t) return string;
  impure function get_id(name : string) return id_t;
  impure function valid(id : id_t) return boolean;
  impure function to_integer(id : id_t) return integer;
  impure function to_id(value : integer) return id_t;
  procedure check(checker : checker_t; id : id_t; subprogram : string);
  procedure check(id : id_t; subprogram : string);

end package;

package body id_pkg is
  type id_db_t is record
    p_data : integer_vector_ptr_t;
  end record;

  constant id_db : id_db_t := (p_data => new_integer_vector_ptr);
  constant id_number_idx : natural := 0;
  constant id_name_idx : natural := 1;

  impure function to_integer(id : id_t) return integer is
  begin
    return to_integer(id.p_data);
  end;

  impure function to_id(value : integer) return id_t is
  begin
    return (p_data => to_integer_vector_ptr(value));
  end;

  impure function new_id(name : string := "") return id_t is
    constant ids : integer_vector_ptr_t := id_db.p_data;
    constant id_number : integer := length(ids);
    variable id : id_t;
  begin
    check(id_checker, get_id(name) = null_id, "An ID named " & name & " already exists.");

    id.p_data := new_integer_vector_ptr(2);

    set(id.p_data, id_number_idx, id_number);

    resize(ids, length(ids) + 1);
    if name = "" then
      set(id.p_data, id_name_idx, to_integer(new_string_ptr("id " & integer'image(id_number))));
    else
      set(id.p_data, id_name_idx, to_integer(new_string_ptr(name)));
    end if;
    set(ids, id_number, to_integer(id));

    return id;
  end;

  impure function valid(id : id_t) return boolean is
  begin
    return id.p_data /= null_integer_vector_ptr;
  end;

  procedure check(checker : checker_t; id : id_t; subprogram : string) is
  begin
    check(checker, valid(id), "Invalid ID in call to " & subprogram & ".");
  end;

  procedure check(id : id_t; subprogram : string) is
  begin
    check(id_checker, id, subprogram);
  end;

  impure function name(id : id_t) return string is
  begin
    check(id, "name");

    return to_string(to_string_ptr(get(id.p_data, id_name_idx)));
  end;

  impure function get_id(name : string) return id_t is
    constant ids : integer_vector_ptr_t := id_db.p_data;
  begin
    for i in 0 to length(ids) - 1 loop
      if work.id_pkg.name(to_id(get(ids, i))) = name then
        return to_id(get(ids, i));
      end if;
    end loop;

    return null_id;
  end;
end package body;
