-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

context vunit_context is
  library vunit_lib;
  context vunit_lib.data_types_context;

  use vunit_lib.string_ops.all;
  use vunit_lib.dictionary.all;
  use vunit_lib.path.all;
  use vunit_lib.print_pkg.all;
  use vunit_lib.log_levels_pkg.all;
  use vunit_lib.logger_pkg.all;
  use vunit_lib.log_handler_pkg.all;
  use vunit_lib.id_pkg.all;
  use vunit_lib.ansi_pkg.all;
  use vunit_lib.checker_pkg.all;
  use vunit_lib.check_pkg.all;
  use vunit_lib.run_types_pkg.all;
  use vunit_lib.run_pkg.all;
  use vunit_lib.runner_pkg.key_t;
  use vunit_lib.event_common_pkg.all;
  use vunit_lib.event_pkg.all;
end context;
