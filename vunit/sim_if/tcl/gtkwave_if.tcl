# Description:
#   This script is the top level that can be used to easily add
#   waveforms to GTKWave waveform viewer.
#
#   depth:
#       This mode allows user to specify desired depth. The script
#       will parse all signals and add every signal inside each hierarchy
#       that is <= user specified depth

# procedure::_getAllWaves
#
proc _getAllWaves {} {
  # init internals
  set paths [list]

  # get number of waves
  set num_waves  [ gtkwave::getNumFacs ]

  # search entire waveform list and remove duplicates
  for {set idx 0} {$idx < $num_waves} {incr idx} {
    lappend paths [ gtkwave::getFacName $idx ]
  }
  return $paths
}

# procedure::_displayWaves
#
proc _displayWaves { dictWaveGroups } {
  set first 0

  foreach {k v} $dictWaveGroups {
    set add_wave [ gtkwave::addSignalsFromList $v ]

    # GTK doesn't highlight the first set of signals added so nothing gets grouped
    if {$first == 0} {
      gtkwave::/Edit/Highlight_All
    }
    gtkwave::/Edit/Create_Group "$k"
    #gtkwave::setLeftJustifySigs on
    gtkwave::/Edit/Toggle_Group_Open|Close
    gtkwave::/Edit/UnHighlight_All

    # TODO: figure out how to determine signal type so we can set data format
    #set flags [ gtkwave::getTraceFlagsFromName {$v} ]
    #puts "$flags"
    incr first
  }
  #gtkwave::/Edit/Set_Trace_Max_Hier 0
  set filename [gtkwave::getSaveFileName]
  puts "$filename"
  # sort groups and update viewer
  gtkwave::/Edit/Highlight_All
  gtkwave::/Edit/Sort/Sigsort_All
  gtkwave::/Edit/UnHighlight_All
  gtkwave::nop
}


# procedure::addWavesByDepth
#
proc addWavesByDepth { depth } {
  set dictGroup [ dict create ]
  set old_path 1

  foreach { path } [ _getAllWaves ] {
    # split path and determine how many elements there are
    set elements     [ split $path . ]
    set num_elements [ llength $elements ]
    incr num_elements -2

    # remove first element because redundant and last because this is the signal name, then join for matching
    set group_elements [ lreplace [ lreplace $elements 0 0 ] end end ]
    set group_name     [ join $group_elements "." ]

    # if we found match, append path to group key
    if {$num_elements <= $depth} {
      set elements [ split $path \[ ]

      if { [ llength $elements ] > 1 } {
        set var [ lreplace $elements end end ]
        set path [ join $var \[ ]
      }

      if {$old_path ne $path} {
        set key $group_name
        set val $path
        dict lappend dictGroup $key $val
        set old_path $path
      }
    }
  }
  _displayWaves $dictGroup
}
