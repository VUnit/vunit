library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

package bfm2_pkg is
  constant write_msg : msg_type_t := new_msg_type("write");
  constant actor : actor_t := new_actor("BFM 2");
end package bfm2_pkg;
