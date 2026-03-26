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
            "push"     { return "C_PUSH" }
            "pop"      { return "C_POP" }
            "label"    { return "C_LABEL" }
            "goto"     { return "C_GOTO" }
            "if-goto"  { return "C_IF" }
            "function" { return "C_FUNCTION" }
            "call"     { return "C_CALL" }
            "return"   { return "C_RETURN" }
            "add" - "sub" - "neg" - "eq" - "gt" - "lt" - "and" - "or" - "not" {
                return "C_ARITHMETIC"
            }
            default { return "UNKNOWN" }
        }
    }

    method arg1 {} {
        set type [my commandType]
        if {$type eq "C_ARITHMETIC"} {
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
    variable call_counter
    variable current_function

    constructor {outfile} {
        set out_fp [open $outfile w]
        set label_counter 0
        set call_counter 0
        set current_function "OS"
    }

    method setFileName {filename} {
        set filename_no_ext [file rootname [file tail $filename]]
    }

    # --- Bootstrap Code ---
    method writeInit {} {
        puts $out_fp "// Bootstrap: SP=256 and call Sys.init"
        puts $out_fp "@256\nD=A\n@SP\nM=D"
        my writeCall Sys.init 0
    }

    # --- Arithmetic & Memory (from Tar1) ---
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
        set label_true "COMP_TRUE_$label_counter"
        set label_end "COMP_END_$label_counter"
        incr label_counter
        puts $out_fp "@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\n@$label_true\nD;$jumpType\n@SP\nA=M-1\nM=0\n@$label_end\n0;JMP\n($label_true)\n@SP\nA=M-1\nM=-1\n($label_end)"
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
                puts $out_fp "@[expr {5 + $index}]\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            } elseif {$segment eq "pointer"} {
                set sym [expr {$index == 0 ? "THIS" : "THAT"}]
                puts $out_fp "@$sym\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
            }
        } else {
            if {$segment in {"local" "argument" "this" "that"}} {
                set sym [my segmentToSymbol $segment]
                puts $out_fp "@$index\nD=A\n@$sym\nD=M+D\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D"
            } elseif {$segment eq "static"} {
                puts $out_fp "@SP\nAM=M-1\nD=M\n@${filename_no_ext}.${index}\nM=D"
            } elseif {$segment eq "temp"} {
                puts $out_fp "@SP\nAM=M-1\nD=M\n@[expr {5 + $index}]\nM=D"
            } elseif {$segment eq "pointer"} {
                set sym [expr {$index == 0 ? "THIS" : "THAT"}]
                puts $out_fp "@SP\nAM=M-1\nD=M\n@$sym\nM=D"
            }
        }
    }

    # --- Program Flow ---
    method writeLabel {label} {
        puts $out_fp "($current_function\$$label)"
    }

    method writeGoto {label} {
        puts $out_fp "@$current_function\$$label\n0;JMP"
    }

    method writeIf {label} {
        puts $out_fp "@SP\nAM=M-1\nD=M\n@$current_function\$$label\nD;JNE"
    }

    # --- Function Commands ---
    method writeFunction {funcName numLocals} {
        set current_function $funcName
        puts $out_fp "($funcName)"
        repeat $numLocals {
            my writePushPop C_PUSH constant 0
        }
    }

    method writeCall {funcName numArgs} {
        set retAddr "RETURN_ADDR_$call_counter"
        incr call_counter
        
        # push returnAddress
        puts $out_fp "@$retAddr\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1"
        # push LCL, ARG, THIS, THAT
        foreach seg {LCL ARG THIS THAT} {
            puts $out_fp "@$seg\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1"
        }
        # ARG = SP - 5 - numArgs
        puts $out_fp "@SP\nD=M\n@5\nD=D-A\n@$numArgs\nD=D-A\n@ARG\nM=D"
        # LCL = SP
        puts $out_fp "@SP\nD=M\n@LCL\nM=D"
        # goto funcName
        puts $out_fp "@$funcName\n0;JMP"
        # (returnAddress)
        puts $out_fp "($retAddr)"
    }

    method writeReturn {} {
        puts $out_fp "// return"
        # endFrame (R14) = LCL
        puts $out_fp "@LCL\nD=M\n@R14\nM=D"
        # retAddr (R15) = *(endFrame - 5)
        puts $out_fp "@5\nA=D-A\nD=M\n@R15\nM=D"
        # *ARG = pop()
        puts $out_fp "@SP\nAM=M-1\nD=M\n@ARG\nA=M\nM=D"
        # SP = ARG + 1
        puts $out_fp "@ARG\nD=M+1\n@SP\nM=D"
        # Restore THAT, THIS, ARG, LCL
        set i 1
        foreach seg {THAT THIS ARG LCL} {
            puts $out_fp "@R14\nD=M\n@$i\nA=D-A\nD=M\n@$seg\nM=D"
            incr i
        }
        # goto retAddr
        puts $out_fp "@R15\nA=M\n0;JMP"
    }

    method segmentToSymbol {segment} {
        switch -exact -- $segment {
            "local"    { return "LCL" }
            "argument" { return "ARG" }
            "this"     { return "THIS" }
            "that"     { return "THAT" }
        }
    }

    method close {} { close $out_fp }
}

# Helper for repeating local initializations
proc repeat {n body} {
    for {set i 0} {$i < $n} {incr i} { uplevel 1 $body }
}

# ---------------------------------------------------------------------
# Main Execution (Supports Directory or File)
# ---------------------------------------------------------------------
if {$argc != 1} {
    puts "Usage: tclsh VMTranslator.tcl <file.vm or directory>"
    exit 1
}

set path [lindex $argv 0]
if {[file isdirectory $path]} {
    set vm_files [glob -directory $path "*.vm"]
    set output_file "[file join $path [file tail $path]].asm"
    set is_dir 1
} else {
    set vm_files [list $path]
    set output_file "[file rootname $path].asm"
    set is_dir 0
}

set writer [CodeWriter new $output_file]

# במידה וזו תיקייה (או קובץ מערכת), עושים Bootstrap
if {$is_dir || [file tail $path] eq "Sys.vm"} {
    $writer writeInit
}

foreach vm_file $vm_files {
    $writer setFileName $vm_file
    set parser [Parser new $vm_file]
    while {[$parser hasMoreLines]} {
        $parser advance
        set type [$parser commandType]
        switch -exact -- $type {
            "C_ARITHMETIC" { $writer writeArithmetic [$parser arg1] }
            "C_PUSH" - "C_POP" { $writer writePushPop $type [$parser arg1] [$parser arg2] }
            "C_LABEL"    { $writer writeLabel [$parser arg1] }
            "C_GOTO"     { $writer writeGoto [$parser arg1] }
            "C_IF"       { $writer writeIf [$parser arg1] }
            "C_FUNCTION" { $writer writeFunction [$parser arg1] [$parser arg2] }
            "C_CALL"     { $writer writeCall [$parser arg1] [$parser arg2] }
            "C_RETURN"   { $writer writeReturn }
        }
    }
}

$writer close
puts "Success: [file tail $output_file] generated."