proc vunit_compile {} {
    set cmd_show {<<recompile_command_visual>>}
    puts "Re-compiling using command ${cmd_show}"

    set chan [open |[list <<recompile_command_eval_tcl>>] r]

    while {[gets $chan line] >= 0} {
        puts $line
    }

    if {[catch {close $chan} error_msg]} {
        puts "Re-compile failed"
        puts ${error_msg}
        return true
    } else {
        puts "Re-compile finished"
        return false
    }
}

proc vunit_restart {} {
    if {![vunit_compile]} {
        _vunit_sim_restart
        vunit_run
    }
}
