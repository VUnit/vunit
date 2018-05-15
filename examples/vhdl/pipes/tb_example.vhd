use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_example is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_example is

begin
  main : process
    file ifile : text;
    file ofile : text;
    variable l : line;
    variable tmp : integer;
  begin
    test_runner_setup(runner, runner_cfg);

    file_open(ifile, output_path(runner_cfg) & "/" & "input", read_mode);
    file_open(ofile, output_path(runner_cfg) & "/" & "output", write_mode);
    while not endfile(ifile) loop
      readline(ifile, l);
      read(l, tmp);
      report to_string(tmp);
      write(l, 11 * tmp);
      writeline(ofile, l);
    end loop;
    file_close(ifile);
    file_close(ofile);

    test_runner_cleanup(runner);
  end process;
end architecture;
