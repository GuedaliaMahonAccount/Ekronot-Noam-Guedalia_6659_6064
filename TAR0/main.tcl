# Global variables for the current file name, output file pointer, and logical command counter
set current_file_name ""
set logical_counter 0
set out_fp ""

# --- Helper Functions ---

# Handle arithmetic and memory commands
proc handleAdd {} {
    global out_fp
    puts $out_fp "command: add"
}

proc handleSub {} {
    global out_fp
    puts $out_fp "command: sub"
}

proc handlNeg {} {
    global out_fp
    puts $out_fp "command: neg"
}

# Handle logical commands (includes counter increment)
proc handleEq {} {
    global out_fp logical_counter
    puts $out_fp "command: eq"
    incr logical_counter
    puts $out_fp "counter: $logical_counter"
}

proc handleGt {} {
    global out_fp logical_counter
    puts $out_fp "command: gt"
    incr logical_counter
    puts $out_fp "counter: $logical_counter"
}

proc handleLt {} {
    global out_fp logical_counter
    puts $out_fp "command: lt"
    incr logical_counter
    puts $out_fp "counter: $logical_counter"
}

# Handle memory access commands (requires segment and index)
proc handlePush {segment index} {
    global out_fp
    puts $out_fp "command: push segment $segment index $index"
}

proc handlePop {segment index} {
    global out_fp
    puts $out_fp "command: pop segment $segment index $index"
}

# --- Main Program ---

# 1. Get directory path from the user
puts -nonewline "Enter directory path: "
flush stdout
gets stdin dir_path

# Clean up path to avoid trailing slashes issues
set clean_dir_path [string trimright $dir_path "/\\"]

# 2. Extract the last directory name to create the .asm output file
set dir_name [file tail $clean_dir_path]
set out_file_name "${dir_name}.asm"

# Open the output file for writing (created in the current working directory)
set out_fp [open $out_file_name w]

# 3. Find all .vm files in the given directory
set vm_files [glob -nocomplain -directory $clean_dir_path *.vm]

# 4. Iterate over each .vm input file
foreach vm_file $vm_files {
    # Reset logical command counter for the new file
    set logical_counter 0
    
    # Extract file name with and without the .vm extension
    set file_tail [file tail $vm_file]
    set current_file_name [file rootname $file_tail]
    
    # Open the input file for reading
    set in_fp [open $vm_file r]
    
    # Read the file line by line
    while {[gets $in_fp line] >= 0} {
        # Trim leading/trailing whitespaces
        set line [string trim $line]
        
        # Skip empty lines
        if {$line eq ""} {
            continue
        }
        
        # Split the line into words
        set words [split $line " \t"]
        
        # Remove empty elements caused by multiple spaces
        set words [lsearch -all -inline -not -exact $words {}]
        
        # Identify the command and call the appropriate helper function
        set cmd [lindex $words 0]
        
        switch -exact -- $cmd {
            "add" { handleAdd }
            "sub" { handleSub }
            "neg" { handlNeg }
            "eq"  { handleEq }
            "gt"  { handleGt }
            "lt"  { handleLt }
            "push" {
                set segment [lindex $words 1]
                set index [lindex $words 2]
                handlePush $segment $index
            }
            "pop" {
                set segment [lindex $words 1]
                set index [lindex $words 2]
                handlePop $segment $index
            }
        }
    }
    
    # Close the input file
    close $in_fp
    
    # Print end of input file message to the screen
    puts "End of input file: $file_tail"
}

# 5. Close the output file
close $out_fp

# Print end of processing message to the screen
puts "Output file is ready: $out_file_name"