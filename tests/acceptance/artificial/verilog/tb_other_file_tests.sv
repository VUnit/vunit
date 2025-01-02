// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

module tb_other_file_tests;
   parameter string runner_cfg = "";
   other_file_tests #(.nested_runner_cfg(runner_cfg)) other_file_tests_inst();
endmodule
