-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.checker_pkg.all;
use work.runner_pkg.all;
use work.run_types_pkg.all;
use work.run_pkg.all;
use work.core_pkg;

package run_deprecated_pkg is
  -- Deprecated interface to better support legacy testbenches.
  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    constant checker_stat : in checker_stat_t);

end package run_deprecated_pkg;

package body run_deprecated_pkg is
  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    constant checker_stat : in checker_stat_t) is
  begin
    warning("Using deprecated procedure test_runner_cleanup with " &
            "checker_stat.");

    failure_if(checker_stat.n_failed > 0, to_string(checker_stat));
    test_runner_cleanup(runner);
  end;
end package body run_deprecated_pkg;
