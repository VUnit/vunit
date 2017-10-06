use work.string_ptr_pkg.all;
use work.integer_vector_ptr_pkg.all;

package body log_pkg is

  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t is
  begin
    return get_logger(log_system, name, parent);
  end;

  impure function is_enabled(logger : logger_t;
                             level : log_level_t) return boolean is
  begin
    return is_enabled(log_system, logger, level);
  end;

  -- Disable logging for all levels < level to this handler
  procedure set_log_level(log_handler : log_handler_t;
                          level : log_level_config_t) is
  begin
    set_log_level(log_system, log_handler, level);
  end;

  -- Disable logging to this handler
  procedure disable_all(log_handler : log_handler_t) is
  begin
    set_log_level(log_system, log_handler, all_levels);
  end;

  -- Enable logging to this handler
  procedure enable_all(log_handler : log_handler_t) is
  begin
    set_log_level(log_system, log_handler, no_level);
  end;

  procedure set_stop_level(level : log_level_config_t) is
  begin
    set_stop_level(log_system.p_root_logger, level);
  end;

  procedure disable_stop is
  begin
    set_stop_level(log_system.p_root_logger, all_levels);
  end;

  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    log(log_system, logger, msg, log_level, line_num, file_name);
  end procedure;

  procedure debug(logger : logger_t;
                  msg : string;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, debug, line_num, file_name);
  end procedure;

  procedure verbose(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, verbose, line_num, file_name);
  end procedure;

  procedure info(logger : logger_t;
                 msg : string;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    log(logger, msg, info, line_num, file_name);
  end procedure;

  procedure warning(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, warning, line_num, file_name);
  end procedure;

  procedure error(logger : logger_t;
                  msg : string;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, error, line_num, file_name);
  end procedure;

  procedure failure(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, failure, line_num, file_name);
  end procedure;

  procedure debug(msg : string;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    debug(default_logger, msg, line_num, file_name);
  end procedure;

  procedure verbose(msg : string;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    verbose(default_logger, msg, line_num, file_name);
  end procedure;

  procedure info(msg : string;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    info(default_logger, msg, line_num, file_name);
  end procedure;

  procedure warning(msg : string;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    warning(default_logger, msg, line_num, file_name);
  end procedure;

  procedure error(msg : string;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    error(default_logger, msg, line_num, file_name);
  end procedure;

  procedure failure(msg : string;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    failure(default_logger, msg, line_num, file_name);
  end procedure;

end package body;
