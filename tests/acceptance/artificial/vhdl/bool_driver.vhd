-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- From Issue 71. Generic overridden on all hiearchy levels.

entity bool_driver is
  generic (
    g_val : boolean := true);
  port (
    outp  : out boolean);
end entity;

architecture rtl of bool_driver is
begin
  outp <= g_val;
end architecture;
