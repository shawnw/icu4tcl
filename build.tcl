#!/usr/bin/env tclsh
# Script to build and install icu4tcl

package require critcl::app

switch [llength $argv] {
    1 {
        # Use-specified path.
        set path [lindex $argv 0]
    }
    0 {
        # Default one.
        set path [info library]
    }
    default {
        puts stderr "Usage: $argv0 TCL_LIBRARY_PATH"
        exit 1
    }
}
puts "Installing to $path"
critcl::app::main [list -pkg -libdir $path icu]
