set signals [list]

proc vunit_wave {args} {
    global signals
    set parsed_args [_vunit_wave_parse_args $args]
    if {$parsed_args != ""} {
        lassign $parsed_args instance depth clean save
    } else {
        return 1
    }

    if {$clean} {
        delete wave *
    }
    _vunit_wave $instance "" $depth
    if {$save} {
        _vunit_wave_save $signals
    }

    # Added all signals, now trigger a wave window update
    wave refresh
}

proc _vunit_wave { instance_name prev_group_option cur_depth} {
    global signals
    # Should be a list something like "/top/inst (MOD1)"
    set breadthwise_instances [find instances $instance_name/*]

    # IFF there are items itterate through them breadthwise
    foreach inst $breadthwise_instances {
        # Separate "/top/inst"  from "(MOD1)"
        set inst_path [lindex [split $inst " "] 0]
        # Get just the end word after last "/"
        set gname     [lrange [split $inst_path "/"] end end]

        # Return upward if bottom of specified limit
        if {$cur_depth != 0} {
            # Recursively call this routine with next level to investigate
            _vunit_wave  "$inst_path"  "$prev_group_option $gname" [expr $cur_depth - 1]
        } else {
            return
        }

    }

    # Avoid including your top level /* as we already have /top/*
    if { $instance_name != "" && [find signals $instance_name/*] != ""} {
        # Echo the wave add command, but you can turn this off
        set cmd "add wave -noupdate -group $prev_group_option $instance_name/*"
        if { [catch { eval $cmd }] } {

        } else {
            echo $cmd
            lappend signals $prev_group_option $instance_name
        }
    }


    # Return up the recursing stack
    return
}

proc _vunit_wave_save {signals} {
   set wave_file [open <<wave_path>> w]
   puts $wave_file "global gui"
   puts $wave_file "set signals \[list  \\"
   foreach {group instance} $signals {
       puts $wave_file "    \"$group\" \"$instance\" \\"
   }
   puts $wave_file "]"
   puts $wave_file "if {! \[info exists gui\]} {"
   puts $wave_file "    set gui 1"
   puts $wave_file "} else {"
   puts $wave_file "    delete wave *"
   puts $wave_file "}"
   puts $wave_file "foreach {group instance } \$signals {"
   puts $wave_file "    if {\$gui} {"
   puts $wave_file "        set cmd \"add wave -noupdate \$group \$instance/*\""
   puts $wave_file "    } else {"
   puts $wave_file "        set cmd \"log \$instance/*\""
   puts $wave_file "    }"
   puts $wave_file "    if { ! \[ catch { eval \$cmd } \] } {"
   puts $wave_file "        puts \$cmd"
   puts $wave_file "    }"
   puts $wave_file "}"
   puts $wave_file "if {\$gui} {"
   puts $wave_file "    wave refresh"
   puts $wave_file "}"
   close $wave_file
   puts "Saved to <<wave_path>>"
}

proc _vunit_wave_parse_args {args} {
    # Remove the brace from end and then split into a list
    set arg_list [regexp -all -inline {\S+} [regsub -all {\{|\}} $args ""]]
    set num_args [llength $arg_list]
    set instance ""
    set depth 1
    set clean 0
    set save 0
    for {set i 0} { $i < [expr $num_args] } {incr i} {
        set arg [lindex $arg_list $i]
        set has_next_arg [expr $i < [expr $num_args - 1]]
        if {$has_next_arg} {
            set next_arg [lindex $arg_list [expr $i + 1]]
        }

        if {[string first "help" $arg] != -1} {
            return [_vunit_wave_help]
        } elseif {[string first "-instance" $arg] != -1 } {
            if {$has_next_arg == 0} {
                puts "No instance specified to -instance"
                return [_vunit_wave_help]
            }
            set instance $next_arg
            incr i

        }  elseif {[string first "-depth" $arg] != -1} {
            if {$has_next_arg == 0} {
                puts "No depth specified to -depth"
                return [_vunit_wave_help]
            }
            set depth $next_arg
            incr i
        } elseif {[string first "-clean" $arg] != -1} {
            set clean 1
        } elseif {[string first "-save" $arg] != -1} {
            set save 1
        } else {
            puts "Invalid argument $arg"
            return [_vunit_wave_help]
        }
    }

    return [list $instance $depth $clean $save]

}


proc _vunit_wave_help {} {
    puts "Usage: vunit_wave \[help\] \[-instance instance\] \[-depth depth\] \[-clean\] \[-save\]"
    puts "  -instance instance:  An instance path of the form /DUT/U_0.  Begins recursion here.       Default: /"
    puts "  -depth depth:        Depth of recursion.  -1 to recurse completely.                       Default: 1"
    puts "  -clean:              Remove all signals from wave before adding.                          Default: 0"
    puts "  -save:               Also save wave.do to tb folder.  Loaded by default on next run.      Default: 0"
    return
}
