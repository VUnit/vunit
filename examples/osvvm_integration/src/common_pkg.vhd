-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.check_types_pkg.all;

library osvvm;
--use osvvm.OsvvmGlobalPkg.all ;
use osvvm.AlertLogPkg.all ;

package common_pkg is
  impure function get_alert_statistics
    return checker_stat_t;
end package common_pkg;

package body common_pkg is
  impure function get_alert_statistics
    return checker_stat_t is
    variable stat : checker_stat_t := (0,0,0);
  begin
    -- OSVVM doesn't keep track of passing alerts other than failing alerts
    -- that has been disabled.
    stat.n_passed := GetDisabledAlertCount;
    stat.n_failed := GetEnabledAlertCount;
    stat.n_checks := stat.n_passed + stat.n_failed;

    return stat;
  end function get_alert_statistics;
end package body common_pkg;
