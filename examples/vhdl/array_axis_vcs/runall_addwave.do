echo "Running DO File"
foreach v "vunit_axism vunit_axiss uut uut/fifo" {
  add wave -group "$v" -position insertpoint sim:/tb_axis_loop/$v/*
}
run -all;
