-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- reflection_check_generic_pkg gives both check_equal procedures of reflection_check_pkg for one type,
-- with one instantiation in an architecture or package:
--
--   package packet_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => packet_t);
--   use packet_checks.all;
--   ...
--   check_equal(got_packet, expected_packet);
--   check_equal(my_checker, got_packet, expected_packet);
--
-- Instances for different types overload on the type. Don't instantiate it as a design unit of its
-- own: on Riviera-PRO 2026.04, check_equal through such an instance silently does nothing. An instance
-- inside a package works.

use work.reflection_check_pkg.all;

package reflection_check_generic_pkg is
  generic (type t);

  procedure check_equal is new work.reflection_check_pkg.check_equal generic map (t => t);
  procedure check_equal is new work.reflection_check_pkg.check_equal_with_checker generic map (t => t);
end package;
