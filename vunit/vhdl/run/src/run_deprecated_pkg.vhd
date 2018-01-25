-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

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
    constant checker_stat : in checker_stat_t;
    constant external_failure : in boolean := false);

end package run_deprecated_pkg;

package body run_deprecated_pkg is
  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    constant checker_stat : in checker_stat_t;
    constant external_failure : in boolean := false) is
  begin
    warning("Using deprecated procedure test_runner_cleanup with " &
            "checker_stat and external_failure input.");

    if external_failure then
      core_pkg.core_failure("External failure.");
      return;
    end if;

    test_runner_cleanup(runner);
  end;
end package body run_deprecated_pkg;
