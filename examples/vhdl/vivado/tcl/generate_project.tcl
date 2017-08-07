# Create a Vivado project to suit the needs of this example
# the reader of this example could generate his vivado project in a similar maner or
# have a manually maintained project.

set root [lindex ${argv} 0]
set project_name [lindex ${argv} 1]

# Create project
create_project -force myproject ${root}/${project_name}

# Configure general project settings
set obj [get_projects myproject]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" "xc7z010clg400-1" $obj

set_property "simulator_language" "Mixed" $obj
set_property "source_mgmt_mode" "DisplayOnly" $obj
set_property "target_language" "VHDL" $obj

# Create ip directory
set ip_dir ${root}/${project_name}_ip
file mkdir ${ip_dir}

# Create one fifo as an example of an IP
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name fifo_8b_32w -dir ${ip_dir}
set_property -dict [list CONFIG.INTERFACE_TYPE {AXI_STREAM} CONFIG.TDATA_NUM_BYTES {1} CONFIG.TUSER_WIDTH {0} CONFIG.FIFO_Implementation_axis {Common_Clock_Distributed_RAM} CONFIG.Input_Depth_axis {32} CONFIG.TSTRB_WIDTH {1} CONFIG.TKEEP_WIDTH {1} CONFIG.FIFO_Implementation_wach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wach {15} CONFIG.Empty_Threshold_Assert_Value_wach {14} CONFIG.FIFO_Implementation_wrch {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wrch {15} CONFIG.Empty_Threshold_Assert_Value_wrch {14} CONFIG.FIFO_Implementation_rach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_rach {15} CONFIG.Empty_Threshold_Assert_Value_rach {14} CONFIG.Full_Threshold_Assert_Value_axis {31} CONFIG.Empty_Threshold_Assert_Value_axis {30}] [get_ips fifo_8b_32w]
