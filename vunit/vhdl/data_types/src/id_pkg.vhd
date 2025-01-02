-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- Description: id_pkg provides a way of creating a hierarchical
-- structure of named objects in a testbench. For an overview see
-- the user guide.

use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.string_ops.all;
use work.core_pkg.all;

use std.textio.all;

package id_pkg is
  -- ID record, all fields are private
  type id_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_id : id_t := (p_data => null_ptr);
  type id_vec_t is array (integer range <>) of id_t;
  constant null_id_vec : id_vec_t := (1 to 0 => null_id);

  -- root_id is a nameless and predefined ID that is the parent to
  -- all user created top-level IDs (no parent was specified at creation)
  -- root_id serves as an entry-point to the tree of all IDs
  impure function root_id return id_t;

  -- Get ID object with given name and parent if it exists. Create a new ID otherwise.
  -- The name string can be with or without hierarchy, for example "a_name" or
  -- "parent_name:child_name". If no parent is given the name is relative to root_id.
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

  -- Return true if an identity with given name already exists, false otherwise.
  -- The name string can be with or without hierarchy, for example "a_name" or
  -- "parent_name:child_name". If no parent is given the name is relative to root_id.
  impure function has_id(name : string; parent : id_t := null_id) return boolean;

  -- Return an ASCII representation of the subtree of IDs rooted in the given ID.
  -- If no ID is given the full ID tree is returned. The returned string starts
  -- with a linefeed character (LF) such that the first line of the tree comes on
  -- a separate line. This will make the first line aligned with the rest of the tree
  -- when printed in a log message. The initial LF can be omitted by setting initial_lf
  -- to false.
  impure function get_tree(id : id_t := null_id; initial_lf : boolean := true) return string;

  -- Return an identity vector where the leftmost identity is root_id and the rightmost
  -- identity is that of the id parameter. The identities in between are the sequence
  -- of descendants leading from root_id to id.
  impure function get_lineage(id : id_t) return id_vec_t;

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

  impure function get_real_parent(parent : id_t) return id_t is
  begin
    if parent = null_id then
      return root_id;
    end if;
    return parent;
  end;

  impure function get_id(name : string; parent : id_t := null_id) return id_t is
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

  procedure null_id_failure(subprogram_name : string) is
  begin
    core_failure(subprogram_name & " is not defined for null_id.");
  end;

  impure function get_parent(id : id_t) return id_t is
  begin
    if id = null_id then
      null_id_failure("get_parent");
      return null_id;
    end if;

    return to_id(get(id.p_data, parent_idx));
  end;

  impure function num_children(id : id_t) return natural is
    variable children : integer_vector_ptr_t;
  begin
    if id = null_id then
      null_id_failure("num_children");
      return 0;
    end if;

    children := to_integer_vector_ptr(get(id.p_data, children_idx));

    return length(children);
  end;

  impure function get_child(id : id_t; idx : natural) return id_t is
    variable children : integer_vector_ptr_t;
  begin
    if id = null_id then
      null_id_failure("get_child");
      return null_id;
    end if;

    children := to_integer_vector_ptr(get(id.p_data, children_idx));

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
     if id = null_id then
      null_id_failure("name");
      return "";
    end if;

    return to_string(to_string_ptr(get(id.p_data, name_idx)));
  end;

  impure function full_name(id : id_t) return string is
    variable parent : id_t;
  begin
     if id = null_id then
      null_id_failure("full_name");
      return "";
    end if;

    parent := get_parent(id);
    if parent = null_id or (parent = root_id) then
      return name(id);
    else
      return full_name(parent) & ":" & name(id);
    end if;
  end;

  impure function has_id(name : string; parent : id_t := null_id) return boolean is
    constant stripped_name : string := strip(name, ":");
    constant real_parent : id_t := get_real_parent(parent);
    variable split_name : lines_t := split(stripped_name, ":", 1);
    constant head_name : string := split_name(0).all;

    variable id, child : id_t;
  begin
    if name = "" then
      return parent = null_id;
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
      return false;
    end if;

    if split_name'length > 1 then
      return has_id(split_name(1).all, id);
    end if;

    return true;
  end;

 impure function get_tree(id : id_t := null_id; initial_lf : boolean := true) return string is
    impure function get_subtree(subtree_root : id_t; child_indentation : string := "") return string is
      variable ret_val : line;
    begin
      if subtree_root = root_id then
        -- The root ID has no name but in pretty-printing it is clearer if it is given a "symbol".
        write(ret_val, string'("(root)"));
      else
        write(ret_val, name(subtree_root));
      end if;

      if num_children(subtree_root) > 0 then
        for idx in 0 to num_children(subtree_root) - 2 loop
          write(ret_val, LF & child_indentation & "+---" & get_subtree(get_child(subtree_root, idx), child_indentation & "|   "));
        end loop;
        write(ret_val, LF & child_indentation & "\---" & get_subtree(get_child(subtree_root, num_children(subtree_root) - 1), child_indentation & "    "));
      end if;

      return ret_val.all;
    end;
  begin
    if id = null_id then
      return get_tree(root_id, initial_lf);
    end if;

    if initial_lf then
      return LF & get_subtree(id);
    end if;

    return get_subtree(id);
  end;

  impure function get_lineage(id : id_t) return id_vec_t is
    impure function get_lineage_i(id : id_t) return id_vec_t is
      variable parts : lines_t := split(full_name(id), ":");
      constant length : positive := parts'length + 1;
      variable lineage : id_vec_t(1 to length);
      variable tmp_id : id_t := id;
    begin
      for idx in length downto 1 loop
        lineage(idx) := tmp_id;
        exit when tmp_id = root_id;
        tmp_id := get_parent(tmp_id);
      end loop;

      return lineage;
    end;
  begin
    if id = null_id then
      null_id_failure("get_lineage");
      return null_id_vec;
    elsif id = root_id then
      return (1 => root_id);
    end if;

    return get_lineage_i(id);
  end;

end package body;
