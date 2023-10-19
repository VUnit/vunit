set project_file [lindex $argv 0]
set output_file [lindex $argv 1]

open_project ${project_file}

set file_out [open ${output_file} w]

# Generate block designs, and any IPs contained by the block designs
generate_target {simulation synthesis} [get_files *.bd]

# Open all block designs otherwise they are not visible through get_bd_designs
foreach bd [get_files *.bd] {
    open_bd_design ${bd}
}

# Generate all IPs not contained in a block design
foreach ip [get_ips -filter {SCOPE == ""}] {
    generate_target {simulation synthesis} ${ip}
}

# Build compilation order for all ips
foreach ip [get_ips] {
    foreach src_file [get_files -used_in simulation -compile_order sources -of_objects ${ip}] {
        set library [get_property LIBRARY ${src_file}]
        set file_type [get_property FILE_TYPE ${src_file}]
        puts ${file_out} "${library},${file_type},${src_file}"
    }
}

# Build compilation order for all block designs
# -quiet is required otherwise get_bd_designs will error if there are no block designs
foreach bd [get_bd_designs -quiet] {
    foreach src_file [get_files -used_in simulation -compile_order sources *${bd}*] {
        set library [get_property LIBRARY ${src_file}]
        set file_type [get_property FILE_TYPE ${src_file}]
        puts ${file_out} "${library},${file_type},${src_file}"
    }
}

close ${file_out}
