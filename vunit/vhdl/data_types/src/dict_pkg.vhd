-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.string_ptr_pool_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;

package dict_pkg is
  type dict_t is record
    p_meta : integer_vector_ptr_t;
    p_bucket_lengths : integer_vector_ptr_t;
    p_bucket_keys : integer_vector_ptr_t;
    p_bucket_values : integer_vector_ptr_t;
  end record;
  constant null_dict : dict_t := (others => null_ptr);

  impure function new_dict return dict_t;
  procedure deallocate(variable dict : inout dict_t);

  procedure set(dict : dict_t; key, value : string);
  impure function get(dict : dict_t; key : string) return string;
  impure function has_key(dict : dict_t; key : string) return boolean;
  impure function num_keys(dict : dict_t) return natural;
  procedure remove(dict : dict_t; key : string);
end package;

package body dict_pkg is
  constant int_pool : integer_vector_ptr_pool_t := allocate;
  constant str_pool : string_ptr_pool_t := allocate;

  constant meta_num_keys : natural := 0;
  constant meta_length : natural := meta_num_keys+1;

  constant new_bucket_size : natural := 1;

  impure function new_dict return dict_t is
    variable dict : dict_t;
    variable tmp : integer_vector_ptr_t;
    constant num_buckets : natural := 1;
  begin
    dict := (p_meta => allocate(int_pool, meta_length),
             p_bucket_lengths => allocate(int_pool, num_buckets),
             p_bucket_keys => allocate(int_pool, num_buckets),
             p_bucket_values => allocate(int_pool, num_buckets));

    set(dict.p_meta, meta_num_keys, 0);

    for i in 0 to length(dict.p_bucket_lengths)-1 loop
      -- Zero items in bucket
      set(dict.p_bucket_lengths, i, 0);

      tmp := allocate(int_pool, new_bucket_size);
      set(dict.p_bucket_keys, i, to_integer(tmp));

      tmp := allocate(int_pool, new_bucket_size);
      set(dict.p_bucket_values, i, to_integer(tmp));
    end loop;
    return dict;
  end function;

  procedure deallocate(variable dict : inout dict_t) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);

    variable bucket_values : integer_vector_ptr_t;
    variable bucket_keys : integer_vector_ptr_t;
    variable bucket_length : natural;

    variable idx : natural;
    variable key_hash : natural;
    variable key : string_ptr_t;
    variable value : string_ptr_t;
  begin
    for bucket_idx in 0 to num_buckets-1 loop
      bucket_keys := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
      bucket_values := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
      bucket_length := get(dict.p_bucket_lengths, bucket_idx);

      for idx in 0 to bucket_length-1 loop
        key := to_string_ptr(get(bucket_keys, idx));
        value := to_string_ptr(get(bucket_values, idx));
        recycle(str_pool, key);
        recycle(str_pool, value);
      end loop;

      recycle(int_pool, bucket_values);
      recycle(int_pool, bucket_keys);
    end loop;

    recycle(int_pool, dict.p_meta);
    recycle(int_pool, dict.p_bucket_lengths);
    recycle(int_pool, dict.p_bucket_values);
    recycle(int_pool, dict.p_bucket_keys);
  end;

  -- DJB2 hash
  impure function hash(str : string) return natural is
    variable value : natural := 5381;
  begin
    for i in str'range loop
      value := (33*value + character'pos(str(i))) mod 2**(31-6);
    end loop;
    return value;
  end function;

  impure function get_value_ptr(dict : dict_t; key_hash : natural; key : string) return string_ptr_t is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    constant bucket_idx : natural := key_hash mod num_buckets;

    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);

    constant bucket_values : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
    constant bucket_keys : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
  begin
    for i in 0 to bucket_length-1 loop
      if to_string(to_string_ptr(get(bucket_keys, i))) = key then
        return to_string_ptr(get(bucket_values, i));
      end if;
    end loop;
    return null_string_ptr;
  end;

  procedure remove(dict : dict_t; bucket_idx : natural; i : natural; deallocate_item : boolean := true) is
    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);
    constant bucket_values : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
    constant bucket_keys : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));

    variable key, value : string_ptr_t;
  begin

    if deallocate_item then
      key := to_string_ptr(get(bucket_keys, i));
      value := to_string_ptr(get(bucket_values, i));
      recycle(str_pool, key);
      recycle(str_pool, value);
    end if;

    set(bucket_keys, i, get(bucket_keys, bucket_length-1));
    set(bucket_values, i, get(bucket_values, bucket_length-1));

    set(dict.p_bucket_lengths, bucket_idx, bucket_length-1);
    set(dict.p_meta, meta_num_keys, num_keys(dict)-1);
  end;

  procedure remove(dict : dict_t; key_hash : natural; key : string) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    constant bucket_idx : natural := key_hash mod num_buckets;

    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);
    constant bucket_keys : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
  begin
    for i in 0 to bucket_length-1 loop
      if to_string(to_string_ptr(get(bucket_keys, i))) = key then
        remove(dict, bucket_idx, i);
        return;
      end if;
    end loop;
  end;

  procedure insert_new(dict : dict_t; key_hash : natural; key, value : string_ptr_t);

  procedure relocate_items(dict : dict_t; old_num_buckets : natural) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    variable bucket_values : integer_vector_ptr_t;
    variable bucket_keys : integer_vector_ptr_t;

    variable idx : natural;
    variable key_hash : natural;
    variable key : string_ptr_t;
    variable value : string_ptr_t;
  begin
    for bucket_idx in 0 to old_num_buckets-1 loop
      bucket_keys := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
      bucket_values := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));

      idx := 0;
      while idx < get(dict.p_bucket_lengths, bucket_idx) loop
        key := to_string_ptr(get(bucket_keys, idx));

        key_hash := hash(to_string(key));
        if key_hash mod num_buckets /= bucket_idx then
          -- Key hash belongs in another bucket now
          value := to_string_ptr(get(bucket_values, idx));

          -- Move key
          remove(dict, bucket_idx, idx, deallocate_item => false);
          insert_new(dict, key_hash, key, value);
        else

          idx := idx + 1;
        end if;
      end loop;

      resize(bucket_keys, get(dict.p_bucket_lengths, bucket_idx));
      resize(bucket_values, get(dict.p_bucket_lengths, bucket_idx));
    end loop;
  end;

  procedure resize(dict : dict_t; num_buckets : natural) is
    constant old_num_buckets : natural := length(dict.p_bucket_lengths);
  begin
    resize(dict.p_bucket_lengths, num_buckets);
    resize(dict.p_bucket_keys, num_buckets);
    resize(dict.p_bucket_values, num_buckets);

    -- Create new buckets
    for i in old_num_buckets to num_buckets-1 loop
      set(dict.p_bucket_keys, i, to_integer(allocate(int_pool, new_bucket_size)));
      set(dict.p_bucket_values, i, to_integer(allocate(int_pool, new_bucket_size)));
      set(dict.p_bucket_lengths, i, 0);
    end loop;

    relocate_items(dict, old_num_buckets);
  end;

  procedure set(dict : dict_t; key, value : string) is
    constant key_hash : natural := hash(key);
    constant old_value_ptr : string_ptr_t := get_value_ptr(dict, key_hash, key);
  begin
    if old_value_ptr /= null_string_ptr then
      -- Reuse existing value storage
      reallocate(old_value_ptr, value);
    else
      insert_new(dict, key_hash, allocate(str_pool, key), allocate(str_pool, value));
    end if;
  end;

  procedure insert_new(dict : dict_t; key_hash : natural; key, value : string_ptr_t) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    constant bucket_idx : natural := key_hash mod num_buckets;

    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);

    constant bucket_values : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
    constant bucket_keys : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
    constant bucket_max_length : natural := length(bucket_values);

    constant num_keys : natural := get(dict.p_meta, meta_num_keys);
  begin
    if num_keys > num_buckets then
      -- Average bucket length is larger than 1, reallocate
      -- Occupancy is to high, resize
      resize(dict, 2*num_buckets);
      insert_new(dict, key_hash, key, value);
      return;

    elsif bucket_length = bucket_max_length then
      -- Bucket size to small, resize
      resize(bucket_keys, bucket_max_length+1);
      resize(bucket_values, bucket_max_length+1);
    end if;

    set(dict.p_meta, meta_num_keys, num_keys+1);
    set(dict.p_bucket_lengths, bucket_idx, bucket_length+1);
    -- Create new value storage
    set(bucket_keys, bucket_length, to_integer(key));
    set(bucket_values, bucket_length, to_integer(value));
  end procedure;

  impure function get(dict : dict_t; key : string) return string is
    constant key_hash : natural := hash(key);
    constant value_ptr : string_ptr_t := get_value_ptr(dict, key_hash, key);
  begin
    assert value_ptr /= null_string_ptr report "missing key '" & key & "'";
    return to_string(value_ptr);
  end;

  impure function has_key(dict : dict_t; key : string) return boolean is
    constant key_hash : natural := hash(key);
  begin
    return get_value_ptr(dict, key_hash, key) /= null_string_ptr;
  end;

  procedure remove(dict : dict_t; key : string) is
    constant key_hash : natural := hash(key);
  begin
    remove(dict, key_hash, key);
  end;

  impure function num_keys(dict : dict_t) return natural is
  begin
    return get(dict.p_meta, meta_num_keys);
  end;

end package body;
