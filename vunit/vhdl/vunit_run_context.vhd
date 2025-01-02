-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

context vunit_run_context is
  library vunit_lib;
  use vunit_lib.dictionary.all;
  use vunit_lib.path.all;
  use vunit_lib.checker_pkg.checker_stat_t;
  use vunit_lib.run_types_pkg.all;
  use vunit_lib.run_pkg.all;
  use vunit_lib.runner_pkg.key_t;
end context;
