set simulator_name [lindex $argv 0]
set simulator_exec_path [lindex $argv 1]
set output_path [lindex $argv 2]

puts "simulator_name=${simulator_name}"
puts "simulator_exec_path=${simulator_exec_path}"
puts "output_path=${output_path}"

set_param general.maxThreads 8
compile_simlib -force \
    -language all \
    -simulator ${simulator_name} \
    -32bit  \
    -verbose  \
    -library unisim \
    -family  all \
    -no_ip_compile \
    -simulator_exec_path ${simulator_exec_path} \
    -directory ${output_path}
