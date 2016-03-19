-- Run special types 200x package provides types specific to VHDL 2002 and 2008.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.run_types_pkg.all;

package run_special_types_pkg is
  type runner_t is protected
     procedure init(active_python_runner : boolean);

     impure function has_active_python_runner return boolean;

     procedure set_phase (
       constant new_phase  : in runner_phase_t);

     impure function get_phase
       return runner_phase_t;

     procedure set_test_case_name (
       constant index : in positive;
       constant new_name  : in string);

     impure function get_test_case_name (
       constant index : positive)
       return string;

     procedure set_num_of_test_cases (
       constant new_value : in integer);

     procedure inc_num_of_test_cases;

     impure function get_num_of_test_cases
       return integer;

     impure function get_active_test_case_index
       return integer;

     procedure inc_active_test_case_index;

     procedure set_test_suite_completed;

     impure function get_test_suite_completed
       return boolean;

     impure function get_test_suite_iteration
       return natural;

     procedure inc_test_suite_iteration;

     procedure set_run_test_case (
       constant index : in positive;
       constant new_name  : in string);

     impure function get_run_test_case (
       constant index : positive)
       return string;

     procedure set_running_test_case (
       constant new_name  : in string);

     impure function get_running_test_case
       return string;

     impure function get_num_of_run_test_cases
       return natural;

     procedure inc_num_of_run_test_cases;

     procedure set_has_run_since_last_loop_check;

     procedure clear_has_run_since_last_loop_check;

     impure function get_has_run_since_last_loop_check
       return boolean;

     procedure set_run_all;

     procedure set_run_all (
       constant new_value : in boolean);

     impure function get_run_all
       return boolean;

     impure function get_test_case_iteration
       return natural;

     procedure inc_test_case_iteration;

     procedure init_test_case_iteration;

     procedure set_test_case_exit_after_error;

     procedure clear_test_case_exit_after_error;

     impure function get_test_case_exit_after_error
       return boolean;

     procedure set_test_suite_exit_after_error;

     procedure clear_test_suite_exit_after_error;

     impure function get_test_suite_exit_after_error
       return boolean;

     procedure set_cfg (
       constant new_value : in string);

     impure function get_cfg
       return string;

  end protected runner_t;

end package;

package body run_special_types_pkg is
  type runner_t is protected body
    variable state : runner_state_t := (
      active_python_runner => false,
      runner_phase => runner_phase_t'left,
      test_case_names => (others => null),
      n_test_cases => unknown_num_of_test_cases_c,
      active_test_case_index => 1,
      test_suite_completed => false,
      test_suite_iteration => 0,
      run_test_cases => (others => null),
      running_test_case_v => null,
      n_run_test_cases => 0,
      has_run_since_last_loop_check => true,
      run_all => true,
      test_case_iteration => 0,
      test_case_exit_after_error => false,
      test_suite_exit_after_error => false,
      runner_cfg => null);

     procedure init(active_python_runner : boolean) is
     begin
       state.active_python_runner := active_python_runner;

       for i in state.test_case_names'range loop
         if state.test_case_names(i) /= null then
           deallocate(state.test_case_names(i));
         end if;
       end loop;

       state.n_test_cases := unknown_num_of_test_cases_c;
       state.active_test_case_index := 1;
       state.test_suite_completed := false;
       state.test_suite_iteration := 0;

       for i in state.run_test_cases'range loop
         if state.run_test_cases(i) /= null then
           deallocate(state.run_test_cases(i));
         end if;
       end loop;

       if state.running_test_case_v /= null then
         deallocate(state.running_test_case_v);
       end if;

       state.n_run_test_cases := 0;
       state.has_run_since_last_loop_check := true;
       state.run_all := true;
       state.test_case_iteration := 0;
       state.test_case_exit_after_error := false;
       state.test_suite_exit_after_error := false;
       state.runner_cfg := new string'(runner_cfg_default);

     end procedure init;

     impure function has_active_python_runner return boolean is
     begin
       return state.active_python_runner;
     end function;

     procedure set_phase (
       constant new_phase  : in runner_phase_t) is
     begin
       state.runner_phase := new_phase;
     end;

     impure function get_phase
       return runner_phase_t is
     begin
       return state.runner_phase;
     end;

     procedure set_test_case_name (
       constant index : in positive;
       constant new_name  : in string) is
     begin
       if state.test_case_names(index) /= null then
         deallocate(state.test_case_names(index));
       end if;
       write(state.test_case_names(index), new_name);
     end;

     impure function get_test_case_name (
       constant index : positive)
       return string is
     begin
       if state.test_case_names(index) /= null then
         return state.test_case_names(index).all;
       else
         return "";
       end if;
     end;

     procedure set_num_of_test_cases (
       constant new_value : in integer) is
     begin
       state.n_test_cases := new_value;
     end;

     procedure inc_num_of_test_cases is
     begin
       state.n_test_cases := state.n_test_cases + 1;
     end;

     impure function get_num_of_test_cases
       return integer is
     begin
       return state.n_test_cases;
     end;

     impure function get_active_test_case_index
       return integer is
     begin
       return state.active_test_case_index;
     end;

     procedure inc_active_test_case_index is
     begin
       state.active_test_case_index := state.active_test_case_index + 1;
     end;

     procedure set_test_suite_completed is
     begin
       state.test_suite_completed := true;
     end;

     impure function get_test_suite_completed
       return boolean is
     begin
       return state.test_suite_completed;
     end;

     impure function get_test_suite_iteration
       return natural is
     begin
       return state.test_suite_iteration;
     end;

     procedure inc_test_suite_iteration is
     begin
       state.test_suite_iteration := state.test_suite_iteration + 1;
     end;

     procedure set_run_test_case (
       constant index : in positive;
       constant new_name  : in string) is
     begin
       if state.run_test_cases(index) /= null then
         deallocate(state.run_test_cases(index));
       end if;
       write(state.run_test_cases(index), new_name);
     end;

     impure function get_run_test_case (
       constant index : positive)
       return string is
     begin
       if state.run_test_cases(index) /= null then
         return state.run_test_cases(index).all;
       else
         return "";
       end if;
     end;

    procedure set_running_test_case (
      constant new_name  : in string) is
    begin
      if state.running_test_case_v /= null then
        deallocate(state.running_test_case_v);
      end if;
      write(state.running_test_case_v, new_name);
    end;

    impure function get_running_test_case
      return string is
    begin
      if state.running_test_case_v /= null then
        return state.running_test_case_v.all;
      else
        return "";
      end if;
    end;

    impure function get_num_of_run_test_cases
      return natural is
    begin
      return state.n_run_test_cases;
    end;

    procedure inc_num_of_run_test_cases is
    begin
      state.n_run_test_cases := state.n_run_test_cases + 1;
    end;

    procedure set_has_run_since_last_loop_check is
    begin
      state.has_run_since_last_loop_check := true;
    end;

    procedure clear_has_run_since_last_loop_check is
    begin
      state.has_run_since_last_loop_check := false;
    end;

    impure function get_has_run_since_last_loop_check
      return boolean is
    begin
      return state.has_run_since_last_loop_check;
    end;

    procedure set_run_all is
    begin
      state.run_all := true;
    end;

   procedure set_run_all (
     constant new_value : in boolean) is
   begin
     state.run_all := new_value;
   end;

    impure function get_run_all
      return boolean is
    begin
      return state.run_all;
    end;

    impure function get_test_case_iteration
      return natural is
    begin
      return state.test_case_iteration;
    end;

    procedure inc_test_case_iteration is
    begin
      state.test_case_iteration := state.test_case_iteration + 1;
    end;

    procedure init_test_case_iteration is
    begin
      state.test_case_iteration := 0;
    end;

    procedure set_test_case_exit_after_error is
    begin
      state.test_case_exit_after_error := true;
    end;

    procedure clear_test_case_exit_after_error is
    begin
      state.test_case_exit_after_error := false;
    end;

    impure function get_test_case_exit_after_error
      return boolean is
    begin
      return state.test_case_exit_after_error;
    end;

    procedure set_test_suite_exit_after_error is
    begin
      state.test_suite_exit_after_error := true;
    end;

    procedure clear_test_suite_exit_after_error is
    begin
      state.test_suite_exit_after_error := false;
    end;

    impure function get_test_suite_exit_after_error
      return boolean is
    begin
      return state.test_suite_exit_after_error;
    end;

    procedure set_cfg (
      constant new_value : in string) is
    begin
      if state.runner_cfg /= null then
        deallocate(state.runner_cfg);
      end if;
      state.runner_cfg := new string'(new_value);
    end;

    impure function get_cfg
      return string is
    begin
      return state.runner_cfg.all;
    end;

  end protected body runner_t;

end package body run_special_types_pkg;
