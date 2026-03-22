#!/usr/bin/env tclsh

# ---------------------------------------------------------------------
# Parser Class
# ---------------------------------------------------------------------
oo::class create Parser {
    variable lines
    variable current_command
    variable current_index

    constructor {filename} {
        set fp [open $filename r]
        set raw_data [read $fp]
        close $fp
        
        set lines {}
        foreach line [split $raw_data "\n"] {
            set line [regsub {//.*} $line ""]
            set line [string trim $line]
            if {$line ne ""} {
                lappend lines $line
            }
        }
        set current_index -1
        set current_command ""
    }

    method hasMoreLines {} {
        return [expr {$current_index < [llength $lines] - 1}]
    }

    method advance {} {
        incr current_index
        set current_command [lindex $lines $current_index]
    }

    method commandType {} {
        set first_word [lindex [split $current_command " "] 0]
        switch -exact -- $first_word {
            "push" { return "C_PUSH" }
            "pop"  { return "C_POP" }
            "add" - "sub" - "neg" - "eq" - "gt" - "lt" - "and" - "or" - "not" {
                return "C_ARITHMETIC"
            }
            default { return "UNKNOWN" }
        }
    }

    method arg1 {} {
        if {[my commandType] eq "C_ARITHMETIC"} {
            return [lindex [split $current_command " "] 0]
        }
        return [lindex [split $current_command " "] 1]
    }

    method arg2 {} {
        return [lindex [split $current_command " "] 2]
    }
}

# ---------------------------------------------------------------------
# CodeWriter Class
# ---------------------------------------------------------------------
oo::class create CodeWriter {
    variable out_fp
    variable filename_no_ext
    variable label_counter

    constructor {outfile} {
        set out_fp [open $outfile w]
        set label_counter 0
    }

    method setFileName {filename} {
        set filename_no_ext [file rootname [file tail $filename]]
    }

    method writeArithmetic {command} {
        puts $out_fp "// $command"
        switch -exact -- $command {
            "add" { puts $out_fp "@SP\nAM=M-1\nD=M\nA=A-1\nM=D+M" }
            "sub" { puts $out_fp "@SP\nAM=M-1\nD=M\nA=A-1\nM=M-D" }
            "and" { puts $out_fp "@SP\nAM=M-1\nD=M\nA=A-1\nM=D&M" }
            "or"  { puts $out_fp "@SP\nAM=M-1\nD=M\nA=A-1\nM=D|M" }
            "neg" { puts $out_fp "@SP\nA=M-1\nM=-M" }
            "not" { puts $out_fp "@SP\nA=M-1\nM=!M" }
            "eq"  { my writeComparison "JEQ" }
            "gt"  { my writeComparison "JGT" }
            "lt"  { my writeComparison "JLT" }
        }
    }

    method writeComparison {jumpType} {
        set label_true "LABEL_TRUE_$label_counter"
        set label_end "LABEL_END_$label_counter"
        incr label_counter
        
        puts $out_fp "@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D"
        puts $out_fp "@$label_true\nD;$jumpType"
        puts $out_fp "@SP\nA=M-1\nM=0"
        puts $out_fp "@$label_end\n0;JMP"
        puts $out_fp "($label_true)\n@SP\nA=M-1\nM=-1"
        puts $out_fp "($label_end)"
    }

    method writePushPop {commandType segment index} {
        puts $out_fp "// [string tolower $commandType] $segment $index"
        
        if {$commandType eq "C_PUSH"} {
            if {$segment eq "constant"} {
                puts $out_fp "@$index\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            } elseif {$segment in {"local" "argument" "this" "that"}} {
                set sym [my segmentToSymbol $segment]
                puts $out_fp "@$index\nD=A\n@$sym\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            } elseif {$segment eq "static"} {
                puts $out_fp "@${filename_no_ext}.${index}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            } elseif {$segment eq "temp"} {
                set addr [expr {5 + $index}]
                puts $out_fp "@$addr\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            } elseif {$segment eq "pointer"} {
                set sym [expr {$index == 0 ? "THIS" : "THAT"}]
                puts $out_fp "@$sym\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            }
        } else {
            # C_POP logic
            if {$segment in {"local" "argument" "this" "that"}} {
                set sym [my segmentToSymbol $segment]
                puts $out_fp "@$index\nD=A\n@$sym\nD=M+D\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D"
            } elseif {$segment eq "static"} {
                puts $out_fp "@SP\nAM=M-1\nD=M\n@${filename_no_ext}.${index}\nM=D"
            } elseif {$segment eq "temp"} {
                set addr [expr {5 + $index}]
                puts $out_fp "@SP\nAM=M-1\nD=M\n@$addr\nM=D"
            } elseif {$segment eq "pointer"} {
                set sym [expr {$index == 0 ? "THIS" : "THAT"}]
                puts $out_fp "@SP\nAM=M-1\nD=M\n@$sym\nM=D"
            }
        }
    }

    method segmentToSymbol {segment} {
        switch -exact -- $segment {
            "local"    { return "LCL" }
            "argument" { return "ARG" }
            "this"     { return "THIS" }
            "that"     { return "THAT" }
        }
    }

    method close {} {
        close $out_fp
    }
}

# ---------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------
if {$argc != 1} {
    puts "Usage: tclsh VMTranslator.tcl <file.vm>"
    exit 1
}

set input_file [lindex $argv 0]
set output_file "[file rootname $input_file].asm"

set parser [Parser new $input_file]
set writer [CodeWriter new $output_file]
$writer setFileName $input_file

while {[$parser hasMoreLines]} {
    $parser advance
    set type [$parser commandType]
    if {$type eq "C_ARITHMETIC"} {
        $writer writeArithmetic [$parser arg1]
    } elseif {$type eq "C_PUSH" || $type eq "C_POP"} {
        $writer writePushPop $type [$parser arg1] [$parser arg2]
    }
}
$writer close
puts "Success: [file tail $output_file] generated."