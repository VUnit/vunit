-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.ansi_pkg.all;
use work.log_levels_pkg.all;
use work.string_ops.upper;
use work.integer_vector_ptr_pkg.all;
use work.path.all;
use work.run_types_pkg.all;
use work.dict_pkg.all;

library osvvm;
use osvvm.AlertLogPkg.all;
use osvvm.TranscriptPkg.all;

package body common_log_pkg is
  constant is_original_pkg : boolean := false;

  constant mode : integer_vector_ptr_t := new_integer_vector_ptr(1);
  constant init_mode : natural := 0;
  constant stdout_mode : natural := 1;
  constant file_mode : natural := 2;
  constant mirror_mode : natural := 3;

  constant last_sequence_number : integer_vector_ptr_t := new_integer_vector_ptr(2, value => -1);
  constant stdout_idx : natural := 0;
  constant file_idx : natural := 1;

  procedure write_to_log(
    file log_destination : text;
    log_destination_path : string := no_string;
    msg : string := no_string;
    log_time : time := no_time;
    log_level : string := no_string;
    log_source_name : string := no_string;
    log_source_path : string;
    log_format : natural range 0 to 3;
    log_source_line_number : natural;
    log_sequence_number : natural;
    use_color : boolean;
    max_logger_name_length : natural

  ) is
    constant stdout : boolean := log_destination_path = no_string;
    constant current_mode : natural range init_mode to mirror_mode := get(mode, 0);
    variable reopen_transcript : boolean := false;
    variable enable_mirror : boolean := false;
  begin
    if stdout and (get(last_sequence_number, stdout_idx) = log_sequence_number) then
      return;
    end if;

    if not stdout and (get(last_sequence_number, file_idx) = log_sequence_number) then
      return;
    end if;

    case current_mode is
      when init_mode =>
        -- Close any open transcript and make sure that the transcript is in the output
        -- path such that several threads do not share the same file
        TranscriptClose;
        SetTranscriptMirror(false);
        if stdout then
          set(last_sequence_number, stdout_idx, log_sequence_number);
          set(mode, 0, stdout_mode);
        else
          TranscriptOpen(join(get_string(run_db, "output_path"), "osvvm_transcript.txt"));
          set(last_sequence_number, file_idx, log_sequence_number);
          set(mode, 0, file_mode);
        end if;
      when stdout_mode =>
        if not stdout then
          TranscriptOpen(join(get_string(run_db, "output_path"), "osvvm_transcript.txt"));
          set(last_sequence_number, file_idx, log_sequence_number);
          set(mode, 0, mirror_mode);
          if get(last_sequence_number, stdout_idx) /= log_sequence_number then
            SetTranscriptMirror;
            set(last_sequence_number, stdout_idx, log_sequence_number);
          else
            enable_mirror := true;
          end if;
        else
          set(last_sequence_number, stdout_idx, log_sequence_number);
        end if;
      when file_mode =>
        if stdout then
          set(last_sequence_number, stdout_idx, log_sequence_number);
          set(mode, 0, mirror_mode);

          if get(last_sequence_number, file_idx) /= log_sequence_number then
            SetTranscriptMirror;
            set(last_sequence_number, file_idx, log_sequence_number);
          else
            TranscriptClose;
            reopen_transcript := true;
          end if;
        else
          set(last_sequence_number, file_idx, log_sequence_number);
        end if;
      when mirror_mode =>
        set(last_sequence_number, stdout_idx, log_sequence_number);
        set(last_sequence_number, file_idx, log_sequence_number);
    end case;

    if (log_level = "warning") or (log_level = "error") or (log_level = "failure") then
      Alert(GetAlertLogID(log_source_name), msg, AlertType'value(upper(log_level)));
    elsif (log_level = "debug") then
      osvvm.AlertLogPkg.Log(GetAlertLogID(log_source_name), msg, DEBUG);
    elsif (log_level = "pass") then
      osvvm.AlertLogPkg.Log(GetAlertLogID(log_source_name), msg, PASSED);
    else
      osvvm.AlertLogPkg.Log(GetAlertLogID(log_source_name), msg);
    end if;

    if reopen_transcript then
      TranscriptOpen(join(get_string(run_db, "output_path"), "osvvm_transcript.txt"), append_mode);
      SetTranscriptMirror;
    end if;

    if enable_mirror then
      SetTranscriptMirror;
    end if;
  end;

end package body;
