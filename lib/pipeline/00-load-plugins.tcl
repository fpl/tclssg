# Tclssg, a static website generator.
# Copyright (c) 2013-2019
# D. Bohdan and contributors listed in AUTHORS. This code is released under
# the terms of the MIT license. See the file LICENSE for details.

# Find Tcl source code files in the plugins/ directory and source them.
namespace eval ::tclssg::pipeline::00-load-plugins {
    namespace path ::tclssg

    proc load files {
        set plugins [db config get plugins 0]

        db transaction {
            set inputDir [db config get inputDir]
            foreach file $files {
                set id [utils::replace-path-root $file $inputDir {}]
                if {[regexp {^/?plugins.*\.tcl$} $id]} {
                    if {$plugins} {
                        log::info "loading plugin [list $file]"
                        source $file
                    } else {
                        log::warn "NOT loading plugin [list $file]"
                    }
                }
            }
        }
    }
}
