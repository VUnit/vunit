-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com
--
-- Description: id_pkg provides an object-oriented approach to handle VHDL name hierarchies
-- programatically. For example, if my_bfm'path_name = ":my_testbench:my_bfm:" then
-- my_bfm_id := get_id(my_bfm'path_name) will create and return an ID for my_bfm but also
-- create an ID for my_testbench. parent(my_bfm_id) will return that ID. If
-- any of the IDs already existed they will not be created but just returned.
--
-- All IDs are unique and have parent-child relationships that create a single global tree
-- of IDs rooted in the root_id. root_id is a predefined nameless parent to all top-level
-- user IDs, for example my_testbench in the previous example.
--
-- While VHDL path_name and instance_name can be used to create ID hierarchies it is also
-- possible to create other hierarchies that have no relation to the name hierarchy defined
-- by VHDL. This is useful when the logical structure is different from the code structure.
-- For example, if my_bfm is wrapped in a block statement to enable local signal declarations
-- the code structure changes and so does the name hierarchy if path_name or instance_name
-- is used. Creating the structure manually with my_bfm_id := get_id("my_testbench:my_bfm")
-- avoids that problem. Note that the leading and trailing ':' present in path_name and
-- instance_name are not needed.

use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.string_ops.all;
use work.core_pkg.all;

package id_pkg is
  -- ID record, all fields are private
  type id_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_id : id_t := (p_data => null_ptr);

  -- root_id is a nameless and predefined ID that is the parent to
  -- all user created top-level IDs (no parent was specified at creation)
  -- root_id serves as an entry-point to the tree of all IDs
  impure function root_id return id_t;

  -- Get ID object with given name and parent if it exists. Create a new ID otherwise.
  -- If no parent is given the ID is a top-level user ID (child to root_id)
  impure function get_id(name : string; parent : id_t := null_id) return id_t;

  impure function get_parent(id : id_t) return id_t;

  -- Return the number of children to id.
  impure function num_children(id : id_t) return natural;

  -- Get the child with index idx. If id has n children legal indices are in the 0 to n - 1
  -- range.
  impure function get_child(id : id_t; idx : natural) return id_t;

  -- Convert id reference to an integer. Useful when storing an ID in a data structure
  -- supporting integer but not id_t.
  impure function to_integer(id : id_t) return integer;

  -- Converting from integer back to id_t.
  impure function to_id(value : integer) return id_t;

  -- Return the full hierarchy name for id, for example "my_testbench:my_bfm".
  impure function full_name(id : id_t) return string;

  -- Return the name for id without hierarchy.
  impure function name(id : id_t) return string;
end package;

package body id_pkg is
  constant id_number_idx : natural := 0;
  constant name_idx : natural := 1;
  constant parent_idx : natural := 2;
  constant children_idx : natural := 3;
  constant id_length : natural := 4;

  constant root_id_number : natural := 0;
  constant next_id_number : integer_vector_ptr_t := new_integer_vector_ptr(1, value => root_id_number + 1);

  impure function new_id(id_number : natural; name : string; parent : id_t) return id_t is
    variable id : id_t;
    variable children : integer_vector_ptr_t;
  begin
    id.p_data := new_integer_vector_ptr(id_length);
    set(id.p_data, id_number_idx, id_number);
    set(id.p_data, name_idx, to_integer(new_string_ptr(name)));
    set(id.p_data, parent_idx, to_integer(parent));
    set(id.p_data, children_idx, to_integer(new_integer_vector_ptr));

    if parent /= null_id then
      children := to_integer_vector_ptr(get(parent.p_data, children_idx));
      resize(children, length(children) + 1);
      set(children, length(children) - 1, to_integer(id));
    end if;

    return id;
  end;

  impure function new_id(name : string; parent : id_t) return id_t is
    constant id_number : natural := get(next_id_number, 0);
  begin
    set(next_id_number, 0, id_number + 1);
    return new_id(id_number, name, parent);
  end;

  impure function get_id(name : string; parent : id_t := null_id) return id_t is
    impure function get_real_parent(parent : id_t) return id_t is
    begin
      if parent = null_id then
        return root_id;
      end if;
      return parent;
    end;

    impure function validate_name(name : string; parent : id_t) return boolean is
      function join(s1, s2 : string) return string is
      begin
        if s1 = "" then
          return s2;
        else
          return s1 & ":" & s2;
        end if;
      end;

      constant full_name : string := join(work.id_pkg.name(parent), name);
    begin
      if (name = "") or (find(full_name, ',') /= 0) then
        core_failure("Invalid ID name """ & full_name & """");
        return false;
      end if;

      return true;
    end;

    constant stripped_name : string := strip(name, ":");
    constant real_parent : id_t := get_real_parent(parent);
    variable split_name : lines_t := split(stripped_name, ":", 1);
    constant head_name : string := split_name(0).all;

    variable id, child : id_t;
  begin
    if not validate_name(head_name, real_parent) then
      return null_id;
    end if;

    id := null_id;
    for i in 0 to num_children(real_parent) - 1 loop
      child := get_child(real_parent, i);

      if work.id_pkg.name(child) = head_name then
        id := child;
        exit;
      end if;
    end loop;

    if id = null_id then
      id := new_id(head_name, real_parent);
    end if;

    if split_name'length > 1 then
      if split_name(1).all /= "" then
        return get_id(split_name(1).all, id);
      end if;
    end if;

    return id;
  end;

  impure function get_parent(id : id_t) return id_t is
  begin
    return to_id(get(id.p_data, parent_idx));
  end;

  impure function num_children(id : id_t) return natural is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(id.p_data, children_idx));
  begin
    return length(children);
  end;

  impure function get_child(id : id_t; idx : natural) return id_t is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(id.p_data, children_idx));
  begin
    return (p_data => to_integer_vector_ptr(get(children, idx)));
  end;

  impure function to_integer(id : id_t) return integer is
  begin
    return to_integer(id.p_data);
  end;

  impure function to_id(value : integer) return id_t is
    variable id : id_t;
  begin
    id.p_data := to_integer_vector_ptr(value);

    return id;
  end;

  impure function new_root_id return id_t is
  begin
    return new_id(root_id_number, "", null_id);
  end;

  constant p_root_id : id_t := new_root_id;
  impure function root_id return id_t is
  begin
    return p_root_id;
  end;

  impure function name(id : id_t) return string is
  begin
    return to_string(to_string_ptr(get(id.p_data, name_idx)));
  end;

  impure function full_name(id : id_t) return string is
    constant parent : id_t := get_parent(id);
  begin
    if parent = null_id or (parent = root_id) then
      return name(id);
    else
      return full_name(parent) & ":" & name(id);
    end if;
  end;

end package body;
