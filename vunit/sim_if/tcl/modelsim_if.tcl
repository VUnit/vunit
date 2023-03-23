# Description:
#   This script is the top level that can be used to easily add
#   waveforms to GTKWave waveform viewer.
#
#   depth:
#       This mode allows user to specify desired depth. The script
#       will parse all signals and add every signal inside each hierarchy
#       that is <= user specified depth

# procedure::_setListUnique
proc _setListUnique {list} {
  array set included_arr [list]
  set unique_list [list]
  foreach item $list {
    if { ![info exists included_arr($item)] } {
      set included_arr($item) ""
      lappend unique_list $item
    }
  }
  unset included_arr
  return $unique_list
}


# procedure::_sortList
proc _sortList { names } {
  return [ lsort -increasing [ _setListUnique $names ] ]
}


# procedure::_getAllSignals
#
proc _getAllSignals {} {
  return [ find signals * -r ]
}


# procedure::_addWaves
#
proc _addWaves { groups } {
  # organize list and remove duplicates
  foreach { group_name } [ _sortList $groups ] {
    set CMD "add wave -noupdate -group $group_name $group_name/*"
    echo $CMD
    eval $CMD
    eval "config wave -signalnamewidth 1"
  }
}


# procedure::addWavesByDepth
#
proc addWavesByDepth { depth } {
  # create dict key/val
  set group_names [ list ]

  # parse list to grab groups we want to add to waveform viewer
  foreach { path } [ _getAllSignals ] {
    # split path and determine how many elements there are
    set elements     [ split $path / ]

    # remove first element because redundant and last because this is the signal name, then join for matching
    set group_elements [ lreplace $elements end end ]
    set group_name     [ join $group_elements "/" ]

    # determine number of elements
    set num_elements [ llength $group_elements ]
    incr num_elements -1

    if {$num_elements <= $depth} {
      lappend group_names $group_name
    }
  }
  _addWaves $group_names
}
