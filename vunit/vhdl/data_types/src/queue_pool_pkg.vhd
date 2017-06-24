-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_ptr_pool_pkg.all;
use work.queue_pkg.all;

package queue_pool_pkg is
  type queue_pool_t is record
    index_pool : integer_vector_ptr_pool_t;
    data_pool : integer_vector_ptr_pool_t;
  end record;
  constant null_queue_pool : queue_pool_t := (others => null_integer_vector_ptr_pool);

  impure function allocate return queue_pool_t;
  impure function allocate(pool : queue_pool_t) return queue_t;
  procedure recycle(pool : queue_pool_t; variable queue : inout queue_t);

end package;

package body queue_pool_pkg is
  impure function allocate return queue_pool_t is
  begin
    return (index_pool => allocate,
            data_pool => allocate);
  end;

  impure function allocate(pool : queue_pool_t) return queue_t is
    variable queue : queue_t;
  begin
    queue := (p_meta => allocate(pool.index_pool, 2),
              data => allocate(pool.data_pool, 0));
    flush(queue);
    return queue;
  end;

  procedure recycle(pool : queue_pool_t; variable queue : inout queue_t) is
  begin
    recycle(pool.index_pool, queue.p_meta);
    recycle(pool.data_pool, queue.data);
  end;

end package body;
