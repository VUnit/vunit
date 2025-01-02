-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
library vunit_lib;
context vunit_lib.vunit_context;
library JSON;
context JSON.json_ctx;

entity tb_json_gens is
  generic (
    runner_cfg : string;
    tb_path    : string;
    tb_cfg     : string
  );
end entity;

architecture tb of tb_json_gens is

begin
  main: process

    procedure run_test(JSONContext : T_JSON) is
      -- get array of integers from JSON content
      constant img_arr : integer_vector := jsonGetIntegerArray(JSONContext, "Image");
    begin
      -- Content extracted from the JSON
      info("JSONContent: " & lf & jsonGetContent(JSONContext));

      -- Integer array, extracted by function jsonGetIntegerArray with data from the JSON
      for i in 0 to img_arr'length-1 loop
        info("Image array [" & integer'image(i) & "]: " & integer'image(img_arr(i)));
      end loop;

      -- Image dimensions as strings, get from the content from the JSON file
      info("Image: " & jsonGetString(JSONContext, "Image/0") & ',' & jsonGetString(JSONContext, "Image/1"));

      -- Some other content, deep in the JSON
      info("Platform/ML505/FPGA: " & jsonGetString(JSONContext, "Platform/ML505/FPGA"));
      info("Platform/KC705/IIC/0/Devices/0/Name: " & jsonGetString(JSONContext, "Platform/KC705/IIC/0/Devices/0/Name"));
    end procedure;

    procedure run_record_test(JSONContext : T_JSON) is
      type img_t is record
        image_width     : positive;
        image_height    : positive;
        dump_debug_data : boolean;
      end record img_t;

      -- fill img_t with content extracted from a JSON input
      constant img : img_t := (
        image_width     => positive'value( jsonGetString(JSONContext, "Image/0") ),
        image_height    => positive'value( jsonGetString(JSONContext, "Image/1") ),
        dump_debug_data => jsonGetBoolean(JSONContext, "dump_debug_data")
      );
    begin
      -- Image dimensions in a record, filled with data from the stringified generic
      info("Image: " & integer'image(img.image_width) & ',' & integer'image(img.image_height));
    end procedure;

    variable JSONContext : T_JSON;

  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      info("RAW generic: " & tb_cfg);
      if run("stringified JSON generic") then
        JSONContext := jsonLoad(tb_cfg);
        run_test(JSONContext);
        run_record_test(JSONContext);
      elsif run("b16encoded stringified JSON generic") then
        JSONContext := jsonLoad(tb_cfg);
        run_test(JSONContext);
        run_record_test(JSONContext);
      elsif run("JSON file path generic") then
        run_test(jsonLoad(tb_path & tb_cfg));
      elsif run("b16encoded JSON file path generic") then
        run_test(jsonLoad(tb_cfg));
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
