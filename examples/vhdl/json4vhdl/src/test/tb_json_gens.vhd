-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.json4vhdl_context;

entity tb_json_gens is
  generic (
    runner_cfg  : string;
    tb_path     : string;
    tb_cfg      : string;
    tb_cfg_file : string := "data/data.json"
  );
end entity;

architecture tb of tb_json_gens is

  -- tb_cfg contains stringified content
  constant JSONContent     : T_JSON := jsonLoad(tb_cfg);

  -- tb_cfg is the path of a JSON file
  constant JSONFileContent : T_JSON := jsonLoad(tb_path & tb_cfg_file);

  -- record to be filled by function decode
  type tb_img_t is record
    image_width     : positive;
    image_height    : positive;
    dump_debug_data : boolean;
  end record tb_img_t;

  -- function to fill tb_img_t with content extracted from a JSON input
  impure function decode(Content : T_JSON) return tb_img_t is
  begin
    return (image_width => positive'value( jsonGetString(Content, "Image/1") ),
            image_height => positive'value( jsonGetString(Content, "Image/2") ),
            dump_debug_data => jsonGetBoolean(Content, "dump_debug_data") );
  end function decode;

  constant tb_img  : tb_img_t := decode(JSONContent);

  -- get array of integers from JSON content. The first element in the array must be the length.
  constant tb_imga : integer_vector := decode_array(JSONContent, "Image");

begin
  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        -- Content extracted from the stringified generic
        info("JSONContent: " & lf & JSONContent.Content);

        -- Full path of the JSON file, and extracted content
        info("tb_path & tb_cfg_file: " & tb_path & tb_cfg_file);
        info("JSONFileContent: " & lf & JSONFileContent.Content);

        -- Image dimensions in a record, filled by function decode with data from the stringified generic
        info("Image: " & integer'image(tb_img.image_width) & ',' & integer'image(tb_img.image_height));

        -- Integer array, extracted by function decode_array with data from the stringified generic
        for i in 0 to tb_imga'length-1 loop
          info("Image array [" & integer'image(i) & "]: " & integer'image(tb_imga(i)));
        end loop;

        -- Image dimensions as strings, get from the content from the JSON file
        info("Image: " & jsonGetString(JSONFileContent, "Image/0") & ',' & jsonGetString(JSONFileContent, "Image/1"));

        -- Some other content, deep in the JSON sources
        info("Platform/ML505/FPGA: " & jsonGetString(JSONContent, "Platform/ML505/FPGA"));
        info("Platform/ML505/FPGA: " & jsonGetString(JSONFileContent, "Platform/ML505/FPGA"));

        info("Platform/KC705/IIC/0/Devices/0/Name: " & jsonGetString(JSONContent, "Platform/KC705/IIC/0/Devices/0/Name"));
        info("Platform/KC705/IIC/0/Devices/0/Name: " & jsonGetString(JSONFileContent, "Platform/KC705/IIC/0/Devices/0/Name"));
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
