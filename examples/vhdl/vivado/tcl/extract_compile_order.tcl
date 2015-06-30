set project [lindex $argv 0]
set output_file [lindex $argv 1]
open_project ${project}

set fp [open ${output_file} w]
foreach xci_file [get_files *.xci] {
    generate_target simulation [get_files $xci_file]
    foreach src_file [get_files -used_in simulation -compile_order sources -of_objects [get_files ${xci_file}]] {
    puts $fp "[get_property LIBRARY ${src_file}],${src_file}"
    }
}
close $fp
