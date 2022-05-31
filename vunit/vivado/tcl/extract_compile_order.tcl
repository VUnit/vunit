set project_file [lindex $argv 0]
set output_file [lindex $argv 1]

open_project ${project_file}

set file_out [open ${output_file} w]
foreach ip [get_ips -filter {SCOPE == ""}] {
    generate_target {simulation synthesis} ${ip}
    foreach src_file [get_files -used_in simulation -compile_order sources -of_objects ${ip}] {
        set library [get_property LIBRARY ${src_file}]
        set file_type [get_property FILE_TYPE ${src_file}]
        puts ${file_out} "${library},${file_type},${src_file}"
    }
}
close ${file_out}
