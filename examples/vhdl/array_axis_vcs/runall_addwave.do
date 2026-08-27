echo "Running DO File"
foreach v "uut_vc/vunit_axism uut_vc/vunit_axiss uut_vc/uut uut_vc/uut/fifo" {
  add wave -group "$v" -position insertpoint sim:/tb_axis_loop/$v/*
}
run -all;
