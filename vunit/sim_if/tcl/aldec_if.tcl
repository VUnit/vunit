# Description:
#   This script is the top level that can be used to easily add
#   waveforms to activeHDL and RivieraPRO waveform viewer.
#
#   depth:
#       This mode allows user to specify desired depth. The script
#       will parse all signals and add every signal inside each hierarchy
#       that is <= user specified depth

# globals because unable to call each of these commands
# within a procedure
find -type signal -rec * {$>} ALL_SIGNALS
find -type instance -rec * {$>} ALL_GROUPS
find -type const -rec * {$>} ALL_CONSTANTS
find -type variable -rec * {$>} ALL_VARIABLES


# procedure::_filterList
#    filters list passed to it for junk Aldec formats it with
proc _filterList {list} {
  # list of items to filter out
  set list_to_filter \
    {"Signals:" "Constants:" "Variables:" "Instances:" "Generics and parameters:"}
  set filt_list {}
  # re-format list created by Aldec
  foreach item $list {
    lappend filt_list [string map {" " ""} $item ]
  }
  # search for and remove all items matching filtered list
  foreach filter $list_to_filter {
    set idx [ lsearch -exact $filt_list $filter ]
    set filt_list [ lreplace $filt_list $idx $idx ]
  }
  # if we find colon, need to only keep anything with a / as this is
  # denoting the hierarchy (what we want) and will remove the crap formatting
  # that Aldec gave to TCL. Aldec puts path before colon, so only keep these elements
  if { [ lsearch -exact $filt_list : ] >= 0 } {
    set tmp {}
    # difficulty searching for /, so using colon instead
    foreach idx [ lsearch -all $filt_list : ] {
      lappend tmp [ lindex $filt_list [expr $idx-1] ]
    }
    set filt_list $tmp
  }
  return $filt_list
}

# procedure::_getAllGroups
#    gets all groups (instance/hierarchy paths)
proc _getAllGroups {} {
  # tell proc to reference global name-space
  global ALL_GROUPS
  return [ _filterList $ALL_GROUPS ]
}

# procedure::_getAllSignals
#    gets all signals
proc _getAllSignals {} {
  # tell proc to reference global name-space
  global ALL_SIGNALS
  return [ _filterList $ALL_SIGNALS ]
}

# procedure::_getAllConstants
#    gets all constants
proc _getAllConstants {} {
  # tell proc to reference global name-space
  global ALL_CONSTANTS
  return [ _filterList $ALL_CONSTANTS ]
}

# procedure::_getAllVariables
#    gets all variables
proc _getAllVariables {} {
  # tell proc to reference global name-space
  global ALL_VARIABLES
  return [ _filterList $ALL_VARIABLES ]
}

# procedure::_addNamedRow
#    add named row to waveform viewer
proc _addNamedRow {name} {
  add wave -named_row $name -height 40 -color red
}

# procedure::_addWaves
#    add all signals within a group to waveform viewer in the order in
#    which they're declared
proc _addWaves {groups} {
  foreach group_name $groups {
    set CMD "add wave -decl -virtual $group_name {$group_name/*}"
    eval $CMD
  }
}

# procedure::_addWave
#    add all signals within a group to waveform viewer in the order in
#    which they're declared
proc _addWave {name} {
  set CMD "add wave -decl $name"
  eval $CMD
}

# procedure::addWavesByDepth
#    adds signals in the hierarchy down to a certain depth
proc addWavesByDepth { depth } {
  # create dict key/val
  set group_names {}

  # parse list to grab groups we want to add to waveform viewer
  foreach { path } [ _getAllGroups ] {
    # split path and determine how many elements there are
    set elements     [ split $path / ]

    # determine number of elements
    set num_elements [ llength $elements ]
    incr num_elements -1

    if {$num_elements <= $depth} {
      lappend group_names $path
    }
  }
  _addWaves $group_names
}
