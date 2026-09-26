-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body dict_pkg is
  constant int_pool : integer_vector_ptr_pool_t := new_integer_vector_ptr_pool;
  constant str_pool : string_ptr_pool_t := new_string_ptr_pool;
  constant meta_num_keys : natural := 0;
  constant meta_length : natural := meta_num_keys+1;
  constant new_bucket_size : natural := 1;

  impure function new_dict
  return dict_t is
    variable dict : dict_t;
    variable tmp : integer_vector_ptr_t;
    constant num_buckets : natural := 1;
  begin
    dict := (p_meta => new_integer_vector_ptr(int_pool, meta_length),
             p_bucket_lengths => new_integer_vector_ptr(int_pool, num_buckets),
             p_bucket_keys => new_integer_vector_ptr(int_pool, num_buckets),
             p_bucket_values => new_integer_vector_ptr(int_pool, num_buckets),
             p_bucket_value_types => new_integer_vector_ptr(int_pool, num_buckets));
    set(dict.p_meta, meta_num_keys, 0);
    for i in 0 to length(dict.p_bucket_lengths)-1 loop
      -- Zero items in bucket
      set(dict.p_bucket_lengths, i, 0);
      tmp := new_integer_vector_ptr(int_pool, new_bucket_size);
      set(dict.p_bucket_keys, i, to_integer(tmp));
      tmp := new_integer_vector_ptr(int_pool, new_bucket_size);
      set(dict.p_bucket_values, i, to_integer(tmp));
      tmp := new_integer_vector_ptr(int_pool, new_bucket_size);
      set(dict.p_bucket_value_types, i, to_integer(tmp));
    end loop;
    return dict;
  end;

  procedure deallocate (
    variable dict : inout dict_t
  ) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);

    variable bucket_values : integer_vector_ptr_t;
    variable bucket_value_types : integer_vector_ptr_t;
    variable bucket_keys : integer_vector_ptr_t;
    variable bucket_length : natural;

    variable key : string_ptr_t;
    variable value : string_ptr_t;
  begin
    for bucket_idx in 0 to num_buckets-1 loop
      bucket_keys := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
      bucket_values := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
      bucket_value_types := to_integer_vector_ptr(get(dict.p_bucket_value_types, bucket_idx));
      bucket_length := get(dict.p_bucket_lengths, bucket_idx);
      for idx in 0 to bucket_length-1 loop
        key := to_string_ptr(get(bucket_keys, idx));
        value := to_string_ptr(get(bucket_values, idx));
        recycle(str_pool, key);
        recycle(str_pool, value);
      end loop;
      recycle(int_pool, bucket_values);
      recycle(int_pool, bucket_value_types);
      recycle(int_pool, bucket_keys);
    end loop;
    recycle(int_pool, dict.p_meta);
    recycle(int_pool, dict.p_bucket_lengths);
    recycle(int_pool, dict.p_bucket_values);
    recycle(int_pool, dict.p_bucket_value_types);
    recycle(int_pool, dict.p_bucket_keys);
  end;

  -- DJB2 hash
  impure function hash (
    str : string
  ) return natural is
    variable value : natural := 5381;
  begin
    for i in str'range loop
      value := (33*value + character'pos(str(i))) mod 2**(31-6);
    end loop;
    return value;
  end;

  impure function get_value_ptr (
    dict     : dict_t;
    key_hash : natural;
    key      : string
  ) return string_ptr_t is
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

  impure function get_value_type (
    dict     : dict_t;
    key_hash : natural;
    key      : string
  ) return data_type_t is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    constant bucket_idx : natural := key_hash mod num_buckets;
    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);
    constant bucket_value_types : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_value_types, bucket_idx));
    constant bucket_keys : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
  begin
    for i in 0 to bucket_length-1 loop
      if to_string(to_string_ptr(get(bucket_keys, i))) = key then
        return data_type_t'val(get(bucket_value_types, i));
      end if;
    end loop;
    return vhdl_character;
  end;

  procedure remove (
    dict            : dict_t;
    bucket_idx      : natural;
    i               : natural;
    deallocate_item : boolean := true
  ) is
    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);
    constant bucket_values : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
    constant bucket_value_types : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_value_types, bucket_idx));
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
    set(bucket_value_types, i, get(bucket_value_types, bucket_length-1));
    set(dict.p_bucket_lengths, bucket_idx, bucket_length-1);
    set(dict.p_meta, meta_num_keys, num_keys(dict)-1);
  end;

  procedure remove (
    dict     : dict_t;
    key_hash : natural;
    key      : string
  ) is
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

  procedure insert_new (
    dict       : dict_t;
    key_hash   : natural;
    key, value : string_ptr_t;
    value_type : data_type_t
  );

  procedure relocate_items (
    dict : dict_t;
    old_num_buckets : natural
  ) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    variable bucket_values : integer_vector_ptr_t;
    variable bucket_value_types : integer_vector_ptr_t;
    variable bucket_keys : integer_vector_ptr_t;
    variable idx : natural;
    variable key_hash : natural;
    variable key : string_ptr_t;
    variable value : string_ptr_t;
    variable value_type : data_type_t;
  begin
    for bucket_idx in 0 to old_num_buckets-1 loop
      bucket_keys := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
      bucket_values := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
      bucket_value_types := to_integer_vector_ptr(get(dict.p_bucket_value_types, bucket_idx));

      idx := 0;
      while idx < get(dict.p_bucket_lengths, bucket_idx) loop
        key := to_string_ptr(get(bucket_keys, idx));

        key_hash := hash(to_string(key));
        if key_hash mod num_buckets /= bucket_idx then
          -- Key hash belongs in another bucket now
          value := to_string_ptr(get(bucket_values, idx));
          value_type := data_type_t'val(get(bucket_value_types, idx));

          -- Move key
          remove(dict, bucket_idx, idx, deallocate_item => false);
          insert_new(dict, key_hash, key, value, value_type);
        else

          idx := idx + 1;
        end if;
      end loop;

      resize(bucket_keys, get(dict.p_bucket_lengths, bucket_idx));
      resize(bucket_values, get(dict.p_bucket_lengths, bucket_idx));
    end loop;
  end;

  procedure resize (
    dict        : dict_t;
    num_buckets : natural
  ) is
    constant old_num_buckets : natural := length(dict.p_bucket_lengths);
  begin
    resize(dict.p_bucket_lengths, num_buckets);
    resize(dict.p_bucket_keys, num_buckets);
    resize(dict.p_bucket_values, num_buckets);
    resize(dict.p_bucket_value_types, num_buckets);

    -- Create new buckets
    for i in old_num_buckets to num_buckets-1 loop
      set(dict.p_bucket_keys, i, to_integer(new_integer_vector_ptr(int_pool, new_bucket_size)));
      set(dict.p_bucket_values, i, to_integer(new_integer_vector_ptr(int_pool, new_bucket_size)));
      set(dict.p_bucket_value_types, i, to_integer(new_integer_vector_ptr(int_pool, new_bucket_size)));
      set(dict.p_bucket_lengths, i, 0);
    end loop;

    relocate_items(dict, old_num_buckets);
  end;

  procedure insert_new (
    dict       : dict_t;
    key_hash   : natural;
    key, value : string_ptr_t;
    value_type : data_type_t
  ) is
    constant num_buckets : natural := length(dict.p_bucket_lengths);
    constant bucket_idx : natural := key_hash mod num_buckets;
    constant bucket_length : natural := get(dict.p_bucket_lengths, bucket_idx);
    constant bucket_values : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_values, bucket_idx));
    constant bucket_value_types : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_value_types, bucket_idx));
    constant bucket_keys : integer_vector_ptr_t := to_integer_vector_ptr(get(dict.p_bucket_keys, bucket_idx));
    constant bucket_max_length : natural := length(bucket_values);
    constant num_keys : natural := get(dict.p_meta, meta_num_keys);
  begin
    if num_keys > num_buckets then
      -- Average bucket length is larger than 1, reallocate
      -- Occupancy is to high, resize
      resize(dict, 2*num_buckets);
      insert_new(dict, key_hash, key, value, value_type);
      return;
    elsif bucket_length = bucket_max_length then
      -- Bucket size to small, resize
      resize(bucket_keys, bucket_max_length+1);
      resize(bucket_values, bucket_max_length+1);
      resize(bucket_value_types, bucket_max_length+1);
    end if;
    set(dict.p_meta, meta_num_keys, num_keys+1);
    set(dict.p_bucket_lengths, bucket_idx, bucket_length+1);
    -- Create new value storage
    set(bucket_keys, bucket_length, to_integer(key));
    set(bucket_values, bucket_length, to_integer(value));
    set(bucket_value_types, bucket_length, data_type_t'pos(value_type));
  end;

  impure function has_key (
    dict : dict_t;
    key  : string
  ) return boolean is
    constant key_hash : natural := hash(key);
  begin
    return get_value_ptr(dict, key_hash, key) /= null_string_ptr;
  end;

  procedure remove (
    dict : dict_t;
    key  : string
  ) is
    constant key_hash : natural := hash(key);
  begin
    remove(dict, key_hash, key);
  end;

  impure function num_keys (
    dict : dict_t
  ) return natural is begin
    return get(dict.p_meta, meta_num_keys);
  end;

  procedure p_set_with_type (
    dict       : dict_t;
    key, value : string;
    value_type : data_type_t
  ) is
    constant key_hash : natural := hash(key);
    constant old_value_ptr : string_ptr_t := get_value_ptr(dict, key_hash, key);
  begin
    if old_value_ptr /= null_string_ptr then
      -- Reuse existing value storage
      reallocate(old_value_ptr, value);
    else
      insert_new(dict, key_hash, new_string_ptr(str_pool, key), new_string_ptr(str_pool, value), value_type);
    end if;
  end;

  impure function p_get_with_type (
    dict : dict_t;
    key  : string;
    expected_value_type : data_type_t
  ) return string is
    constant key_hash : natural := hash(key);
    constant value_ptr : string_ptr_t := get_value_ptr(dict, key_hash, key);
    constant stored_value_type : data_type_t := get_value_type(dict, key_hash, key);
  begin
    assert value_ptr /= null_string_ptr report "missing key '" & key & "'";
    if expected_value_type /= stored_value_type then
      report "Stored value for " & key & " is of type " & to_string(stored_value_type) &
        " but get function for " & to_string(expected_value_type) & " was called." severity error;
    end if;
    return to_string(value_ptr);
  end;

  procedure set_string (
    dict       : dict_t;
    key        : string;
    value      : string
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_string);
  end;

  impure function get_string (
    dict : dict_t;
    key  : string
  ) return string is
  begin
    return decode(p_get_with_type(dict, key, vhdl_string));
  end;

  procedure set_integer (
    dict       : dict_t;
    key        : string;
    value      : integer
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_integer);
  end;

  impure function get_integer (
    dict : dict_t;
    key  : string
  ) return integer is
  begin
    return decode(p_get_with_type(dict, key, vhdl_integer));
  end;

  procedure set_character (
    dict       : dict_t;
    key        : string;
    value      : character
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_character);
  end;

  impure function get_character (
    dict : dict_t;
    key  : string
  ) return character is
  begin
    return decode(p_get_with_type(dict, key, vhdl_character));
  end;

  procedure set_boolean (
    dict       : dict_t;
    key        : string;
    value      : boolean
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_boolean);
  end;

  impure function get_boolean (
    dict : dict_t;
    key  : string
  ) return boolean is
  begin
    return decode(p_get_with_type(dict, key, vhdl_boolean));
  end;

  procedure set_real (
    dict       : dict_t;
    key        : string;
    value      : real
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_real);
  end;

  impure function get_real (
    dict : dict_t;
    key  : string
  ) return real is
  begin
    return decode(p_get_with_type(dict, key, vhdl_real));
  end;

  procedure set_bit (
    dict       : dict_t;
    key        : string;
    value      : bit
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_bit);
  end;

  impure function get_bit (
    dict : dict_t;
    key  : string
  ) return bit is
  begin
    return decode(p_get_with_type(dict, key, vhdl_bit));
  end;

  procedure set_std_ulogic (
    dict       : dict_t;
    key        : string;
    value      : std_ulogic
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_std_ulogic);
  end;

  impure function get_std_ulogic (
    dict : dict_t;
    key  : string
  ) return std_ulogic is
  begin
    return decode(p_get_with_type(dict, key, ieee_std_ulogic));
  end;

  procedure set_severity_level (
    dict       : dict_t;
    key        : string;
    value      : severity_level
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_severity_level);
  end;

  impure function get_severity_level (
    dict : dict_t;
    key  : string
  ) return severity_level is
  begin
    return decode(p_get_with_type(dict, key, vhdl_severity_level));
  end;

  procedure set_file_open_status (
    dict       : dict_t;
    key        : string;
    value      : file_open_status
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_file_open_status);
  end;

  impure function get_file_open_status (
    dict : dict_t;
    key  : string
  ) return file_open_status is
  begin
    return decode(p_get_with_type(dict, key, vhdl_file_open_status));
  end;

  procedure set_file_open_kind (
    dict       : dict_t;
    key        : string;
    value      : file_open_kind
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_file_open_kind);
  end;

  impure function get_file_open_kind (
    dict : dict_t;
    key  : string
  ) return file_open_kind is
  begin
    return decode(p_get_with_type(dict, key, vhdl_file_open_kind));
  end;

  procedure set_bit_vector (
    dict       : dict_t;
    key        : string;
    value      : bit_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_bit_vector);
  end;

  impure function get_bit_vector (
    dict : dict_t;
    key  : string
  ) return bit_vector is
  begin
    return decode(p_get_with_type(dict, key, vhdl_bit_vector));
  end;

  procedure set_std_ulogic_vector (
    dict       : dict_t;
    key        : string;
    value      : std_ulogic_vector
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_std_ulogic_vector);
  end;

  impure function get_std_ulogic_vector (
    dict : dict_t;
    key  : string
  ) return std_ulogic_vector is
  begin
    return decode(p_get_with_type(dict, key, ieee_std_ulogic_vector));
  end;

  procedure set_complex (
    dict       : dict_t;
    key        : string;
    value      : complex
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_complex);
  end;

  impure function get_complex (
    dict : dict_t;
    key  : string
  ) return complex is
  begin
    return decode(p_get_with_type(dict, key, ieee_complex));
  end;

  procedure set_complex_polar (
    dict       : dict_t;
    key        : string;
    value      : complex_polar
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_complex_polar);
  end;

  impure function get_complex_polar (
    dict : dict_t;
    key  : string
  ) return complex_polar is
  begin
    return decode(p_get_with_type(dict, key, ieee_complex_polar));
  end;

  procedure set_numeric_bit_unsigned (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_bit.unsigned
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_numeric_bit_unsigned);
  end;

  impure function get_numeric_bit_unsigned (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_bit.unsigned is
  begin
    return decode(p_get_with_type(dict, key, ieee_numeric_bit_unsigned));
  end;

  procedure set_numeric_bit_signed (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_bit.signed
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_numeric_bit_signed);
  end;

  impure function get_numeric_bit_signed (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_bit.signed is
  begin
    return decode(p_get_with_type(dict, key, ieee_numeric_bit_signed));
  end;

  procedure set_numeric_std_unsigned (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_std.unsigned
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_numeric_std_unsigned);
  end;

  impure function get_numeric_std_unsigned (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_std.unsigned is
  begin
    return decode(p_get_with_type(dict, key, ieee_numeric_std_unsigned));
  end;

  procedure set_numeric_std_signed (
    dict       : dict_t;
    key        : string;
    value      : ieee.numeric_std.signed
  ) is
  begin
    p_set_with_type(dict, key, encode(value), ieee_numeric_std_signed);
  end;

  impure function get_numeric_std_signed (
    dict : dict_t;
    key  : string
  ) return ieee.numeric_std.signed is
  begin
    return decode(p_get_with_type(dict, key, ieee_numeric_std_signed));
  end;

  procedure set_time (
    dict       : dict_t;
    key        : string;
    value      : time
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vhdl_time);
  end;

  impure function get_time (
    dict : dict_t;
    key  : string
  ) return time is
  begin
    return decode(p_get_with_type(dict, key, vhdl_time));
  end;

  procedure set_dict_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout dict_t
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vunit_dict_t);
    value := null_dict;
  end;

  impure function get_dict_t_ref (
    dict : dict_t;
    key  : string
  ) return dict_t is
  begin
    return decode(p_get_with_type(dict, key, vunit_dict_t));
  end;

  procedure set_integer_vector_ptr_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout integer_vector_ptr_t
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vunit_integer_vector_ptr_t);
    value := null_integer_vector_ptr;
  end;

  impure function get_integer_vector_ptr_t_ref (
    dict : dict_t;
    key  : string
  ) return integer_vector_ptr_t is
  begin
    return decode(p_get_with_type(dict, key, vunit_integer_vector_ptr_t));
  end;

  procedure set_string_ptr_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout string_ptr_t
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vunit_string_ptr_t);
    value := null_string_ptr;
  end;

  impure function get_string_ptr_t_ref (
    dict : dict_t;
    key  : string
  ) return string_ptr_t is
  begin
    return decode(p_get_with_type(dict, key, vunit_string_ptr_t));
  end;

  procedure set_integer_array_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout integer_array_t
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vunit_integer_array_t);
    value := null_integer_array;
  end;

  impure function get_integer_array_t_ref (
    dict : dict_t;
    key  : string
  ) return integer_array_t is
  begin
    return decode(p_get_with_type(dict, key, vunit_integer_array_t));
  end;

  procedure set_queue_t_ref (
    dict       : dict_t;
    key        : string;
    value : inout queue_t
  ) is
  begin
    p_set_with_type(dict, key, encode(value), vunit_queue_t);
    value := null_queue;
  end;

  impure function get_queue_t_ref (
    dict : dict_t;
    key  : string
  ) return queue_t is
  begin
    return decode(p_get_with_type(dict, key, vunit_queue_t));
  end;

  procedure push_ref (
    constant queue : queue_t;
    value : inout dict_t
  ) is
  begin
    push_type(queue, vunit_dict_t);
    unsafe_push(queue, value.p_meta);
    unsafe_push(queue, value.p_bucket_lengths);
    unsafe_push(queue, value.p_bucket_keys);
    unsafe_push(queue, value.p_bucket_values);
    unsafe_push(queue, value.p_bucket_value_types);
    value := null_dict;
  end;

  impure function pop_ref(
    queue : queue_t
  ) return dict_t is
  begin
    check_type(queue, vunit_dict_t);
    return (
      p_meta => unsafe_pop(queue),
      p_bucket_lengths => unsafe_pop(queue),
      p_bucket_keys => unsafe_pop(queue),
      p_bucket_values => unsafe_pop(queue),
      p_bucket_value_types => unsafe_pop(queue));
  end;

  function encode (
    data : dict_t
  ) return string is
  begin
    return encode(data.p_meta) & encode(data.p_bucket_lengths) & encode(data.p_bucket_keys) &
    encode(data.p_bucket_values) & encode(data.p_bucket_value_types);
  end;

  function decode (
    code : string
  ) return dict_t is
    variable result : dict_t;
    variable index : positive := code'left;
  begin
    decode(code, index, result);

    return result;
  end;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out dict_t
  ) is
  begin
    decode(code, index, result.p_meta);
    decode(code, index, result.p_bucket_lengths);
    decode(code, index, result.p_bucket_keys);
    decode(code, index, result.p_bucket_values);
    decode(code, index, result.p_bucket_value_types);
  end;

end package body;
