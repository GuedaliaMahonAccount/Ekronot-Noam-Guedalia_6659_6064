package provide SymbolTable 1.0

oo::class create SymbolTable {
    variable classScope
    variable subroutineScope
    variable counts

    constructor {} {
        # Initialize the scopes as empty dictionaries
        set classScope [dict create]
        set subroutineScope [dict create]
        
        # Track the index counts for each kind
        set counts [dict create static 0 field 0 arg 0 var 0]
    }

    method startSubroutine {} {
        # Reset the subroutine scope for a new function/method
        set subroutineScope [dict create]
        dict set counts arg 0
        dict set counts var 0
    }

    method define {name type kind} {
        # Determine current index and increment
        set index [dict get $counts $kind]
        dict set counts $kind [expr {$index + 1}]

        # Save to the appropriate scope
        set symbolData [list type $type kind $kind index $index]
        if {$kind eq "static" || $kind eq "field"} {
            dict set classScope $name $symbolData
        } else {
            dict set subroutineScope $name $symbolData
        }
    }

    method varCount {kind} {
        # Return the number of variables of the given kind
        return [dict get $counts $kind]
    }

    method kindOf {name} {
        # Look in subroutine scope first, then class scope
        if {[dict exists $subroutineScope $name]} {
            return [dict get $subroutineScope $name kind]
        } elseif {[dict exists $classScope $name]} {
            return [dict get $classScope $name kind]
        }
        return "NONE"
    }

    method typeOf {name} {
        if {[dict exists $subroutineScope $name]} {
            return [dict get $subroutineScope $name type]
        } elseif {[dict exists $classScope $name]} {
            return [dict get $classScope $name type]
        }
        return ""
    }

    method indexOf {name} {
        if {[dict exists $subroutineScope $name]} {
            return [dict get $subroutineScope $name index]
        } elseif {[dict exists $classScope $name]} {
            return [dict get $classScope $name index]
        }
        return -1
    }
}