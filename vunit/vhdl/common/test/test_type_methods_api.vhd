-- This file provides the API for the test type methods.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use work.test_types.all;

package test_type_methods is
  procedure get (
    variable sint : inout shared_natural;
    variable value : out natural);
  procedure set (
    variable sint : inout shared_natural;
    constant value : natural);
  procedure add (
    variable sint : inout shared_natural;
    constant value : natural);
end package test_type_methods;
