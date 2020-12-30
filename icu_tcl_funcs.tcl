# Pure tcl functions

namespace eval icu {
    variable version 0.5
    namespace export {[a-z]*}
}

namespace eval icu::char {
    namespace export {[a-z]*}
    namespace ensemble create
}

namespace eval icu::char::is {
    namespace export {[a-z]*}
    namespace ensemble create
}

namespace eval icu::string {
    proc equal args {
        set nargs [llength $args]
        if {$nargs < 2 || $nargs > 5} {
            error "icu::string equal ?-equivalence? ?-nocase? ?-exclude-special-i? string1 string2"
        }
        expr {[compare {*}$args] == 0}
    }

    namespace export {[a-z]*}
    namespace ensemble create
}

namespace eval icu::locale {
    namespace export {[a-z]*}
    namespace ensemble create
}

namespace eval icu::format {
    namespace export {[a-z]*}
    namespace ensemble create
}
