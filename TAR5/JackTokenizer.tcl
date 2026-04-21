package provide JackTokenizer 1.0

oo::class create JackTokenizer {
    variable keywords
    variable symbols
    variable tokens
    variable currentIndex
    variable currentType
    variable currentValue

    constructor {filePath} {
        set keywords {
            class constructor function method field static var int char boolean void
            true false null this let do if else while return
        }
        set symbols {\{ \} \( \) \[ \] . , ; + - * / & | < > = ~}

        set tokens {}
        set currentIndex -1
        set currentType ""
        set currentValue ""

        set fp [open $filePath r]
        set content [read $fp]
        close $fp

        set cleanContent [my removeComments $content]
        set tokens [my tokenize $cleanContent]
    }

    method removeComments {content} {
        set result ""
        set inString 0
        set inLineComment 0
        set inBlockComment 0
        set i 0
        set n [string length $content]

        while {$i < $n} {
            set ch [string index $content $i]
            set next ""
            if {$i + 1 < $n} {
                set next [string index $content [expr {$i + 1}]]
            }

            if {$inLineComment} {
                if {$ch eq "\n"} {
                    set inLineComment 0
                    append result $ch
                }
                incr i
                continue
            }

            if {$inBlockComment} {
                if {$ch eq "*" && $next eq "/"} {
                    set inBlockComment 0
                    incr i 2
                } else {
                    incr i
                }
                continue
            }

            if {!$inString && $ch eq "/" && $next eq "/"} {
                set inLineComment 1
                incr i 2
                continue
            }

            if {!$inString && $ch eq "/" && $next eq "*"} {
                set inBlockComment 1
                incr i 2
                continue
            }

            if {$ch eq "\""} {
                set inString [expr {!$inString}]
            }

            append result $ch
            incr i
        }

        return $result
    }

    method tokenize {content} {
        set out {}
        set i 0
        set n [string length $content]

        while {$i < $n} {
            set ch [string index $content $i]

            if {[string is space $ch]} {
                incr i
                continue
            }

            if {$ch eq "\""} {
                incr i
                set start $i
                while {$i < $n && [string index $content $i] ne "\""} {
                    incr i
                }
                set strVal [string range $content $start [expr {$i - 1}]]
                lappend out [list STRING_CONST $strVal]
                incr i
                continue
            }

            if {$ch in $symbols} {
                lappend out [list SYMBOL $ch]
                incr i
                continue
            }

            if {[string is digit -strict $ch]} {
                set start $i
                while {$i < $n && [string is digit -strict [string index $content $i]]} {
                    incr i
                }
                set intVal [string range $content $start [expr {$i - 1}]]
                lappend out [list INT_CONST $intVal]
                continue
            }

            if {[regexp {[A-Za-z_]} $ch]} {
                set start $i
                while {$i < $n && [regexp {[A-Za-z0-9_]} [string index $content $i]]} {
                    incr i
                }
                set word [string range $content $start [expr {$i - 1}]]
                if {[lsearch -exact $keywords $word] >= 0} {
                    lappend out [list KEYWORD [string toupper $word]]
                } else {
                    lappend out [list IDENTIFIER $word]
                }
                continue
            }

            error "Unexpected character '$ch' in tokenizer"
        }

        return $out
    }

    method hasMoreTokens {} {
        return [expr {$currentIndex + 1 < [llength $tokens]}]
    }

    method advance {} {
        if {![my hasMoreTokens]} {
            return 0
        }

        incr currentIndex
        lassign [lindex $tokens $currentIndex] currentType currentValue
        return 1
    }

    method tokenType {} {
        return $currentType
    }

    method keyword {} {
        return $currentValue
    }

    method symbol {} {
        return $currentValue
    }

    method identifier {} {
        return $currentValue
    }

    method intVal {} {
        return $currentValue
    }

    method stringVal {} {
        return $currentValue
    }
}
