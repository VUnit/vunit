// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

package vunit_pkg;

class test_runner;
   typedef enum {idle,
                 init,
                 test_suite_setup,
                 test_case_setup,
                 test_case,
                 test_case_cleanup,
                 test_suite_cleanup}
                phase_t;

   phase_t phase = idle;
   string       test_cases_found[$];
   string       test_cases_to_run[$];
   string       output_path;
   int          test_idx = 0;
   int          exit_without_errors = 0;
   int          exit_simulation = 0;
   int          trace_fd;

   function automatic string search_replace(string original, string old, string replacement);
      // First find the index of the old string
      int 	start_index = 0;
      int 	original_index = 0;
      int 	replace_index = 0;
      bit 	found = 0;

      while(1) begin
	 if (original[original_index] == old[replace_index]) begin
            if (replace_index == 0) begin
               start_index = original_index;
            end
            replace_index++;
            original_index++;
            if (replace_index == old.len()) begin
               found = 1;
               break;
            end
	 end else if (replace_index != 0) begin
            replace_index = 0;
            original_index = start_index + 1;
	 end else begin
            original_index++;
	 end
	 if (original_index == original.len()) begin
            // Not found
            break;
	 end
      end

      if (!found) return original;

      return {
	      original.substr(0, start_index-1),
	      replacement,
	      original.substr(start_index+old.len(), original.len()-1)
	      };

   endfunction

   function int setup(string runner_cfg);
      // Ugly hack pending actual dictionary parsing
      string    prefix;
      int       index;

      prefix = "enabled_test_cases : ";
      index = -1;
      for (int i=0; i<runner_cfg.len(); i++) begin
	 if (runner_cfg.substr(i, i+prefix.len()-1) == prefix) begin
	    index = i + prefix.len();
	    break;
	 end
      end

      if (index == -1) begin
	 $error("Internal error: Cannot find 'enabled_test_cases' key");
      end

      for (int i=index; i<runner_cfg.len(); i++) begin
	 if (i == runner_cfg.len()-1) begin
            test_cases_to_run.push_back(runner_cfg.substr(index, i));
	 end
         else if (runner_cfg[i] == ",") begin
            test_cases_to_run.push_back(runner_cfg.substr(index, i-1));
            index = i+2;
            i++;
            if (runner_cfg[i] != ",") begin
               break;
            end
         end
      end

      prefix = "output path : ";
      index = -1;
      for (int i=0; i<runner_cfg.len(); i++) begin
	 if (runner_cfg.substr(i, i+prefix.len()-1) == prefix) begin
	    index = i + prefix.len();
	    break;
	 end
      end

      if (index == -1) begin
	 $error("Internal error: Cannot find 'output path' key");
      end

      for (int i=index; i<runner_cfg.len(); i++) begin
	 if (i == runner_cfg.len()-1) begin
            output_path = runner_cfg.substr(index, i);
            break;
	 end
         else if (runner_cfg[i] == ",") begin
            i++;
            if (runner_cfg[i] != ",") begin
               output_path = runner_cfg.substr(index, i-2);
               break;
            end
         end
      end
      output_path = search_replace(output_path, "::", ":");

      phase = idle;
      test_idx = 0;
      exit_without_errors = 0;
      exit_simulation = 0;

      trace_fd = $fopen({output_path, "vunit_results"}, "w");
      return 1;
   endfunction;

   function void cleanup();
      exit_without_errors = 1;
      exit_simulation = 1;
      $stop(0);
   endfunction

   function int loop();
      int       exit_without_errors;

      if (phase == init) begin
         if (test_cases_to_run[0] == "__all__") begin
            test_cases_to_run = test_cases_found;
         end else begin
            int found;
            foreach (test_cases_to_run[j]) begin
               found = 0;
               foreach (test_cases_found[i]) begin
                  if (test_cases_found[i] == test_cases_to_run[j]) begin
                     found = 1;
                     break;
                  end
               end
               if (!found) begin
                  $error("Found no \"%s\" test case", test_cases_to_run[j]);
                  cleanup();
                  return 0;
               end
            end
         end
      end;

      if (phase == test_case_cleanup) begin
         test_idx++;
         if (test_idx < test_cases_to_run.size()) begin
            phase = test_case_setup;
         end else begin
            phase = test_suite_cleanup;
         end
      end else if (phase == test_suite_cleanup) begin
         $fwrite(trace_fd, "test_suite_done\n");
         cleanup();
         return 0;
      end else begin
         phase = phase_t'(phase + 1);
      end

      return 1;
   endfunction

   function int run(string test_name);
      if (phase == init) begin
         test_cases_found.push_back(test_name);
         return 0;
      end else if (phase == test_case && test_name == test_cases_to_run[test_idx]) begin
         $fwrite(trace_fd, "test_start:%s\n", test_name);
         return 1;
      end else begin
         return 0;
      end
   endfunction

   function int is_test_case_setup();
      return phase == test_case_setup;
   endfunction;

   function int is_test_case_cleanup();
      return phase == test_case_cleanup;
   endfunction;

   function int is_test_suite_setup();
      return phase == test_suite_setup;
   endfunction;

   function int is_test_suite_cleanup();
      return phase == test_suite_cleanup;
   endfunction;

   task automatic watchdog(realtime timeout);
      fork : wait_or_timeout
         begin
            #timeout;
            $error("Timeout waiting finish after %.3f ns", timeout / 1ns);
            disable wait_or_timeout;
         end
         begin
            @(posedge exit_without_errors);
            disable wait_or_timeout;
         end
      join
   endtask;

endclass

   test_runner __runner__ = new;
endpackage
