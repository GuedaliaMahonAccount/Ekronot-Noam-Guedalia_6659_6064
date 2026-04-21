package provide CompilationEngine 1.0

oo::class create CompilationEngine {
    variable tokenizer
    variable vmWriter
    variable symbolTable
    variable className
    variable labelCounter

    constructor {jackTokenizer outFilename} {
        set tokenizer $jackTokenizer
        set vmWriter [VMWriter new $outFilename]
        set symbolTable [SymbolTable new]
        set labelCounter 0
    }

    # Helper function to map symbol table kinds to VM segments
    method getSegment {kind} {
        switch -exact -- $kind {
            "field" {return "this"}
            "var"   {return "local"}
            "arg"   {return "argument"}
            "static" {return "static"}
            default {return ""}
        }
    }

    method compileClass {} {
        # Advance tokenizer and get class name
        # ...
        # Loop through classVarDec and subroutineDec
    }

    method compileLet {} {
        # Process the 'let' keyword
        $tokenizer advance
        
        # Get variable name
        set varName [$tokenizer identifier]
        $tokenizer advance
        
        # Check for array access e.g., let a[i] = ...
        set isArray 0
        if {[$tokenizer symbol] eq "\["} {
            set isArray 1
            # Compile the index expression
            # ...
        }

        # Expect '='
        $tokenizer advance

        # Compile the expression on the right side
        my compileExpression

        # Expect ';'
        $tokenizer advance

        # Assign value to the variable via VM commands
        if {$isArray} {
            # Logic for array assignment (pop temp 0, pop pointer 1, push temp 0, pop that 0)
        } else {
            set kind [$symbolTable kindOf $varName]
            set index [$symbolTable indexOf $varName]
            set segment [my getSegment $kind]
            $vmWriter writePop $segment $index
        }
    }

    method compileExpression {} {
        # Compile term
        my compileTerm

        # Loop while there is an operator (+, -, *, /, &, |, <, >, =)
        # while {[$tokenizer symbol] in $operators} ...
        #   compileTerm
        #   writeArithmetic command based on operator
        #   (Remember: '*' calls Math.multiply and '/' calls Math.divide)
    }

    method close {} {
        $vmWriter close
    }


    method compileIf {} {
        # Advance past the 'if' keyword
        $tokenizer advance
        
        # Expect '('
        $tokenizer advance
        
        # Compile the condition expression
        my compileExpression
        
        # Expect ')'
        $tokenizer advance
        
        # Generate unique labels for flow control to handle nested if-statements
        set labelTrue "IF_TRUE$labelCounter"
        set labelFalse "IF_FALSE$labelCounter"
        set labelEnd "IF_END$labelCounter"
        incr labelCounter
        
        # Write VM commands for conditional and unconditional jumps
        $vmWriter writeIf $labelTrue
        $vmWriter writeGoto $labelFalse
        $vmWriter writeLabel $labelTrue
        
        # Expect '{'
        $tokenizer advance
        
        # Compile the statements inside the 'if' block
        my compileStatements
        
        # Expect '}'
        $tokenizer advance
        
        # Jump to the end of the if-structure
        $vmWriter writeGoto $labelEnd
        
        # Label for the false branch
        $vmWriter writeLabel $labelFalse
        
        # Check if an 'else' clause exists
        if {[$tokenizer tokenType] eq "KEYWORD" && [$tokenizer keyword] eq "ELSE"} {
            # Advance past 'else'
            $tokenizer advance
            
            # Expect '{'
            $tokenizer advance
            
            # Compile the statements inside the 'else' block
            my compileStatements
            
            # Expect '}'
            $tokenizer advance
        }
        
        # Write the end label for the entire if-else structure
        $vmWriter writeLabel $labelEnd
    }

    method compileWhile {} {
        # Generate unique labels for the while loop
        set labelExp "WHILE_EXP$labelCounter"
        set labelEnd "WHILE_END$labelCounter"
        incr labelCounter
        
        # Write the label for condition evaluation
        $vmWriter writeLabel $labelExp
        
        # Advance past the 'while' keyword
        $tokenizer advance
        
        # Expect '('
        $tokenizer advance
        
        # Compile the loop condition
        my compileExpression
        
        # Negate the condition (bitwise not)
        $vmWriter writeArithmetic "not"
        
        # If the negated condition is true, jump to the end (exit loop)
        $vmWriter writeIf $labelEnd
        
        # Expect ')'
        $tokenizer advance
        
        # Expect '{'
        $tokenizer advance
        
        # Compile the statements inside the loop body
        my compileStatements
        
        # Expect '}'
        $tokenizer advance
        
        # Jump back to evaluate the condition again
        $vmWriter writeGoto $labelExp
        
        # Write the end label for loop exit
        $vmWriter writeLabel $labelEnd
    }

    method compileDo {} {
        # Advance past the 'do' keyword
        $tokenizer advance
        
        # Extract the subroutine or class/object name
        set identifier [$tokenizer identifier]
        $tokenizer advance
        
        set nArgs 0
        
        # Check if it is a method call on an object or a static function call
        if {[$tokenizer symbol] eq "."} {
            # Advance past '.'
            $tokenizer advance
            
            set subName [$tokenizer identifier]
            $tokenizer advance
            
            # Look up the identifier in the symbol table
            set type [$symbolTable typeOf $identifier]
            
            if {$type ne ""} {
                # The identifier is an object. Push it as the first argument.
                set kind [$symbolTable kindOf $identifier]
                set index [$symbolTable indexOf $identifier]
                
                $vmWriter writePush [my getSegment $kind] $index
                
                set callName "${type}.${subName}"
                set nArgs 1
            } else {
                # The identifier is a class name. This is a static function call.
                set callName "${identifier}.${subName}"
            }
        } else {
            # No '.', this is a method call on the current object ('this')
            $vmWriter writePush "pointer" 0
            set callName "${className}.${identifier}"
            set nArgs 1
        }
        
        # Expect '('
        $tokenizer advance
        
        # Compile the expression list and add the returned count to nArgs
        set nArgs [expr {$nArgs + [my compileExpressionList]}]
        
        # Expect ')'
        $tokenizer advance
        
        # Expect ';'
        $tokenizer advance
        
        # Write the actual VM call command
        $vmWriter writeCall $callName $nArgs
        
        # Discard the return value (void functions always return 0 in VM)
        $vmWriter writePop "temp" 0
    }
}