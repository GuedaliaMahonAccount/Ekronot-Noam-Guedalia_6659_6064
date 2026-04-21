# JackCompiler: Top-level driver for the Jack to VM Compiler
# Part of Project 11 - Nand2Tetris
# Comments are in English as per requirements

# Source the necessary modules
# Ensure these files are in the same directory
source [file join [file dirname [info script]] "SymbolTable.tcl"]
source [file join [file dirname [info script]] "VMWriter.tcl"]
source [file join [file dirname [info script]] "CompilationEngine.tcl"]

# Note: The JackTokenizer is assumed to be part of your previous project.
# You can source it here or ensure it's provided as a class.
# If your Project 10 was procedural, ensure it's wrapped or sourced correctly.
source [file join [file dirname [info script]] "JackTokenizer.tcl"]

proc main {argv} {
    # 1. Check command line arguments
    if {[llength $argv] != 1} {
        puts "Usage: tclsh JackCompiler.tcl <source>"
        puts "source: a .jack file or a directory containing .jack files"
        exit 1
    }

    set inputPath [lindex $argv 0]
    set files {}

    # 2. Determine if input is a file or a directory
    if {[file isdirectory $inputPath]} {
        # Search for all .jack files in the directory
        set files [glob -nocomplain -directory $inputPath *.jack]
    } elseif {[file extension $inputPath] eq ".jack"} {
        # Single .jack file
        set files [list $inputPath]
    } else {
        puts "Error: Input must be a .jack file or a directory."
        exit 1
    }

    if {[llength $files] == 0} {
        puts "Error: No .jack files found in $inputPath"
        exit 1
    }

    # 3. Process each .jack file
    foreach jackFile $files {
        # Generate output filename: same path, change extension to .vm
        set vmFile "[file rootname $jackFile].vm"
        
        puts "Compiling $jackFile ..."

        # 4. Initialize components for each file
        # Create a tokenizer for the input file
        set tokenizer [JackTokenizer new $jackFile]
        
        # Create the compilation engine which handles SymbolTable and VMWriter internally
        # or takes them as arguments based on your implementation
        if {[catch {
            set engine [CompilationEngine new $tokenizer $vmFile]
            
            # Start the recursive top-down compilation from the class level
            $engine compileClass
            
            # Close the engine and its associated file streams
            $engine close
            
            # Cleanup objects
            $engine destroy
            $tokenizer destroy
            
            puts "Successfully generated [file tail $vmFile]"
        } err]} {
            puts "Error compiling $jackFile: $err"
        }
    }
    
    puts "Compilation complete."
}

# Execute the main procedure
main $argv