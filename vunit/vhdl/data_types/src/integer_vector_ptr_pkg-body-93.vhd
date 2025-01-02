-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body integer_vector_ptr_pkg is
  type storage_t is record
    id     : integer;
    mode   : storage_mode_t;
    length : integer;
  end record;
  constant null_storage : storage_t := (integer'low, internal, integer'low);

  type storage_vector_t is array (natural range <>) of storage_t;
  type storage_vector_access_t is access storage_vector_t;

  type ptr_storage is record
    idx   : natural;
    ptr   : natural;
    eptr  : natural;
    idxs  : storage_vector_access_t;
    ptrs  : vava_t;
    eptrs : evava_t;
  end record;

  shared variable st : ptr_storage := (0, 0, 0, null, null, null);

  procedure reallocate_ptrs (
    acc    : inout vava_t;
    length : integer
  ) is
    variable old : vava_t := acc;
  begin
    if old = null then
      acc := new vav_t'(0 => null);
    elsif old'length <= length then
      -- Reallocate ptr pointers to larger ptr; use more size to trade size for speed
      acc     := new vav_t'(0 to acc'length + 2**16 => null);
      for i in old'range loop acc(i) := old(i); end loop;
      deallocate(old);
    end if;
  end;

  procedure reallocate_eptrs (
    acc    : inout evava_t;
    length : integer
  ) is
    variable old : evava_t := acc;
  begin
    if old = null then
      acc := new evav_t'(0 => null);
    elsif old'length <= length then
      acc := new evav_t'(0 to acc'length + 2**16 => null);
      for i in old'range loop acc(i) := old(i); end loop;
      deallocate(old);
    end if;
  end;

  procedure reallocate_ids (
    acc    : inout storage_vector_access_t;
    length : integer
  ) is
    variable old : storage_vector_access_t := acc;
  begin
    if old = null then
      acc := new storage_vector_t(0 to 0);
    elsif old'length <= length then
      acc := new storage_vector_t(0 to acc'length + 2**16);
      for i in old'range loop acc(i) := old(i); end loop;
      deallocate(old);
    end if;
  end;

  impure function new_integer_vector_ptr (
    length : natural := 0;
    mode   : storage_mode_t := internal;
    eid    : index_t := -1;
    value  : val_t   := 0
  ) return ptr_t is begin
    reallocate_ids(st.idxs, st.idx);
    if mode = internal then
      assert eid = -1 report "mode internal: id/=-1 not supported" severity error;
    else
      assert eid /= -1 report "mode external: id must be natural" severity error;
    end if;
    case mode is
      when internal =>
        st.idxs(st.idx) := (
          id     => st.ptr,
          mode   => internal,
          length => 0
        );
        reallocate_ptrs(st.ptrs, st.ptr);
        st.ptrs(st.ptr) := new vec_t'(0 to length-1 => value);
        st.ptr := st.ptr + 1;
      when extacc =>
        st.idxs(st.idx) := (
          id     => st.eptr,
          mode   => extacc,
          length => length
        );
        reallocate_eptrs(st.eptrs, st.eptr);
        st.eptrs(st.eptr) := get_ptr(eid);
        st.eptr := st.eptr + 1;
      when extfnc =>
        st.idxs(st.idx) := (
          id     => eid,
          mode   => extfnc,
          length => length
        );
    end case;
    st.idx := st.idx + 1;
    return (ref => st.idx-1);
  end;

  impure function is_external (
    ptr : ptr_t
  ) return boolean is begin
    return st.idxs(ptr.ref).mode /= internal;
  end;

  -- @TODO Remove check_external when all the functions/procedures are implemented
  procedure check_external (
    ptr : ptr_t;
    s   : string
  ) is begin
    assert not is_external(ptr) report s & " not implemented for external model" severity error;
  end;

  procedure deallocate (
    ptr : ptr_t
  ) is
    variable s : storage_t := st.idxs(ptr.ref);
  begin
    -- @TODO Implement deallocate for external models
    check_external(ptr, "deallocate");
    deallocate(st.ptrs(s.id));
    st.ptrs(s.id) := null;
  end;

  impure function length (
    ptr : ptr_t
  ) return integer is
    variable s : storage_t := st.idxs(ptr.ref);
  begin
    case s.mode is
      when internal => return st.ptrs(s.id)'length;
      when others   => return abs(s.length);
    end case;
  end;

  procedure set (
    ptr   : ptr_t;
    index : natural;
    value : val_t
  ) is
    variable s : storage_t := st.idxs(ptr.ref);
  begin
    case s.mode is
      when extfnc   => write_integer(s.id, index, value);
      when extacc   => st.eptrs(s.id)(index) := value;
      when internal => st.ptrs(s.id)(index) := value;
    end case;
  end;

  impure function get (
    ptr   : ptr_t;
    index : natural
  ) return val_t is
    variable s : storage_t := st.idxs(ptr.ref);
  begin
    case s.mode is
      when extfnc   => return read_integer(s.id, index);
      when extacc   => return st.eptrs(s.id)(index);
      when internal => return st.ptrs(s.id)(index);
    end case;
  end;

  procedure reallocate (
    ptr    : ptr_t;
    length : natural;
    value  : val_t := 0
  ) is
    variable s : storage_t := st.idxs(ptr.ref);
  begin
    case s.mode is
      when extfnc  =>
        -- @FIXME The reallocation request is just ignored. What should we do here?
        --check_external(ptr, "reallocate");
      when extacc   =>
        -- @TODO Implement reallocate for external models (through access)
        check_external(ptr, "reallocate");
      when internal =>
        deallocate(st.ptrs(s.id));
        st.ptrs(s.id) := new vec_t'(0 to length - 1 => value);
    end case;
  end;

  procedure resize (
    ptr    : ptr_t;
    length : natural;
    drop   : natural := 0;
    value  : val_t   := 0
  ) is
    variable oldp, newp : integer_vector_access_t;
    variable min_len : natural := length;
    variable s : storage_t := st.idxs(ptr.ref);
  begin
    case s.mode is
      when internal =>
        newp := new vec_t'(0 to length-1 => value);
        oldp := st.ptrs(s.id);
        if min_len > oldp'length - drop then
          min_len := oldp'length - drop;
        end if;
        for i in 0 to min_len-1 loop
          newp(i) := oldp(drop + i);
        end loop;
        st.ptrs(s.id) := newp;
        deallocate(oldp);
      when others =>
        -- @TODO Implement resize for external models
        check_external(ptr, "resize");
      end case;
  end;

  function to_integer (
    value : ptr_t
  ) return integer is begin
    return value.ref;
  end;

  impure function to_integer_vector_ptr (
    value : val_t
  ) return ptr_t is begin
    -- @TODO maybe assert that the ref is valid
    return (ref => value);
  end;

  function encode (
    data : ptr_t
  ) return string is begin
    return encode(data.ref);
  end;

  function decode (
    code : string
  ) return ptr_t is
    variable ret_val : ptr_t;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);
    return ret_val;
  end;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out ptr_t
  ) is begin
    decode(code, index, result.ref);
  end;

end package body;
