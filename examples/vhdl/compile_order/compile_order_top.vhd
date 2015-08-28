-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

entity compile_order_top is
end entity compile_order_top;

architecture compile_order_top_arch of compile_order_top is
begin
  compile_order_inst : entity work.compile_order;
end architecture compile_order_top_arch;
