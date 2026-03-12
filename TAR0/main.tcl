# --- Helper Functions for Commands --- [cite: 95]

proc handleAdd {outChannel} {
    puts $outChannel "command: add"
}

proc handleSub {outChannel} {
    puts $outChannel "command: sub"
}

proc handleNeg {outChannel} {
    puts $outChannel "command: neg"
}

# Logical commands include a counter 
proc handleEq {outChannel counterVar} {
    upvar $counterVar c
    puts $outChannel "command: eq"
    puts $outChannel "counter: $c"
    set c [expr $c + 1]
}

proc handleGt {outChannel counterVar} {
    upvar $counterVar c
    puts $outChannel "command: gt"
    puts $outChannel "counter: $c"
    set c [expr $c + 1]
}

proc handleLt {outChannel counterVar} {
    upvar $counterVar c
    puts $outChannel "command: lt"
    puts $outChannel "counter: $c"
    set c [expr $c + 1]
}

# Memory access commands with parameters 
proc handlePush {outChannel segment index} {
    puts $outChannel "command: push segment $segment index $index"
}

proc handlePop {outChannel segment index} {
    puts $outChannel "command: pop segment $segment index $index"
}

# --- Main Logic ---

# 1. Get directory path from user [cite: 80]
puts -nonewline "Please enter the directory path: "
flush stdout
set dirPath [gets stdin]

# 2. Extract folder name and create .asm file [cite: 83, 84]
set folderName [file tail $dirPath]
set outputFileName [file join $dirPath "$folderName.asm"]
set outChannel [open $outputFileName w] [cite: 85]

# 3. Iterate through all .vm files in directory [cite: 86]
set vmFiles [glob -nocomplain -directory $dirPath *.vm]

foreach vmFile $vmFiles {
    # Define logical counter and reset it [cite: 88]
    set logicalCounter 0
    
    # Store filename globally without extension [cite: 89]
    global currentFileName
    set currentFileName [file rootname [file tail $vmFile]]
    
    # Open VM file for reading [cite: 90]
    set inChannel [open $vmFile r] [cite: 91]
    
    while {[gets $inChannel line] >= 0} {
        # Trim and split line into words [cite: 93]
        set words [regexp -all -inline {\S+} $line]
        if {[llength $words] == 0} continue
        
        set cmd [lindex $words 0]
        
        # 4. Route to helper functions [cite: 94]
        switch $cmd {
            "add" { handleAdd $outChannel }
            "sub" { handleSub $outChannel }
            "neg" { handleNeg $outChannel }
            "eq"  { handleEq $outChannel logicalCounter }
            "gt"  { handleGt $outChannel logicalCounter }
            "lt"  { handleLt $outChannel logicalCounter }
            "push" { handlePush $outChannel [lindex $words 1] [lindex $words 2] }
            "pop"  { handlePop $outChannel [lindex $words 1] [lindex $words 2] }
        }
    }
    
    close $inChannel [cite: 99]
    puts "End of input file: [file tail $vmFile]" [cite: 100, 101]
}

close $outChannel
puts "Output file is ready: $folderName.asm" [cite: 104, 105]