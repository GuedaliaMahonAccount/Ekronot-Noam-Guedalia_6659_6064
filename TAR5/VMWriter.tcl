package provide VMWriter 1.0

oo::class create VMWriter {
    variable fileId

    constructor {filename} {
        # Open the output VM file for writing
        set fileId [open $filename w]
    }

    method writePush {segment index} {
        # Write a VM push command
        puts $fileId "push $segment $index"
    }

    method writePop {segment index} {
        # Write a VM pop command
        puts $fileId "pop $segment $index"
    }

    method writeArithmetic {command} {
        # Write a VM arithmetic/logical command
        puts $fileId $command
    }

    method writeLabel {label} {
        # Write a label command
        puts $fileId "label $label"
    }

    method writeGoto {label} {
        # Write an unconditional goto command
        puts $fileId "goto $label"
    }

    method writeIf {label} {
        # Write a conditional if-goto command
        puts $fileId "if-goto $label"
    }

    method writeCall {name nArgs} {
        # Write a function call command
        puts $fileId "call $name $nArgs"
    }

    method writeFunction {name nLocals} {
        # Write a function declaration command
        puts $fileId "function $name $nLocals"
    }

    method writeReturn {} {
        # Write a return command
        puts $fileId "return"
    }

    method close {} {
        # Close the file stream
        close $fileId
    }
}