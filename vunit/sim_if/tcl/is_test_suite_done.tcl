proc is_test_suite_done {} {
    set fd [open "<<vunit_result_file>>" "r"]
    set contents [read $fd]
    close $fd
    set lines [split $contents "\n"]
    foreach line $lines {
        if {$line=="test_suite_done"} {
           return true;
        }
    }

    return false;
}