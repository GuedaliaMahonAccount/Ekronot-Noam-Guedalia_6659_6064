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
        set className ""
        set labelCounter 0
    }

    method errorHere {message} {
        error "Compilation error: $message (tokenType=[$tokenizer tokenType], token=[$tokenizer identifier])"
    }

    method getSegment {kind} {
        switch -exact -- $kind {
            field  {return this}
            var    {return local}
            arg    {return argument}
            static {return static}
            default {return ""}
        }
    }

    method newLabel {prefix} {
        set label "$prefix.$labelCounter"
        incr labelCounter
        return $label
    }

    method parseType {{allowVoid 0}} {
        set tt [$tokenizer tokenType]
        if {$tt eq "KEYWORD"} {
            set kw [string tolower [$tokenizer keyword]]
            if {$kw in {int char boolean} || ($allowVoid && $kw eq "void")} {
                $tokenizer advance
                return $kw
            }
            my errorHere "Expected type keyword, got '$kw'"
        }

        if {$tt eq "IDENTIFIER"} {
            set t [$tokenizer identifier]
            $tokenizer advance
            return $t
        }

        my errorHere "Expected type"
    }

    method eatKeyword {kw} {
        if {[$tokenizer tokenType] ne "KEYWORD" || [$tokenizer keyword] ne $kw} {
            my errorHere "Expected keyword '$kw'"
        }
        $tokenizer advance
    }

    method eatSymbol {sym} {
        if {[$tokenizer tokenType] ne "SYMBOL" || [$tokenizer symbol] ne $sym} {
            my errorHere "Expected symbol '$sym'"
        }
        $tokenizer advance
    }

    method eatIdentifier {} {
        if {[$tokenizer tokenType] ne "IDENTIFIER"} {
            my errorHere "Expected identifier"
        }
        set name [$tokenizer identifier]
        $tokenizer advance
        return $name
    }

    method pushVariable {name} {
        set kind [$symbolTable kindOf $name]
        if {$kind eq "NONE"} {
            my errorHere "Undefined variable '$name'"
        }
        set segment [my getSegment $kind]
        set index [$symbolTable indexOf $name]
        $vmWriter writePush $segment $index
    }

    method popVariable {name} {
        set kind [$symbolTable kindOf $name]
        if {$kind eq "NONE"} {
            my errorHere "Undefined variable '$name'"
        }
        set segment [my getSegment $kind]
        set index [$symbolTable indexOf $name]
        $vmWriter writePop $segment $index
    }

    method compileClass {} {
        $tokenizer advance
        my eatKeyword CLASS
        set className [my eatIdentifier]
        my eatSymbol "{"

        while {[$tokenizer tokenType] eq "KEYWORD" && ([$tokenizer keyword] eq "STATIC" || [$tokenizer keyword] eq "FIELD")} {
            my compileClassVarDec
        }

        while {[$tokenizer tokenType] eq "KEYWORD" && ([$tokenizer keyword] eq "CONSTRUCTOR" || [$tokenizer keyword] eq "FUNCTION" || [$tokenizer keyword] eq "METHOD")} {
            my compileSubroutine
        }

        my eatSymbol "}"
    }

    method compileClassVarDec {} {
        set kind [string tolower [$tokenizer keyword]]
        $tokenizer advance

        set type [my parseType]
        set name [my eatIdentifier]
        $symbolTable define $name $type $kind

        while {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ","} {
            $tokenizer advance
            set name [my eatIdentifier]
            $symbolTable define $name $type $kind
        }

        my eatSymbol ";"
    }

    method compileSubroutine {} {
        $symbolTable startSubroutine

        set subroutineType [string tolower [$tokenizer keyword]]
        $tokenizer advance

        my parseType 1
        set subroutineName [my eatIdentifier]

        if {$subroutineType eq "method"} {
            $symbolTable define this $className arg
        }

        my eatSymbol "("
        my compileParameterList
        my eatSymbol ")"

        my eatSymbol "{"
        while {[$tokenizer tokenType] eq "KEYWORD" && [$tokenizer keyword] eq "VAR"} {
            my compileVarDec
        }

        set nLocals [$symbolTable varCount var]
        $vmWriter writeFunction "$className.$subroutineName" $nLocals

        if {$subroutineType eq "constructor"} {
            set nFields [$symbolTable varCount field]
            $vmWriter writePush constant $nFields
            $vmWriter writeCall Memory.alloc 1
            $vmWriter writePop pointer 0
        } elseif {$subroutineType eq "method"} {
            $vmWriter writePush argument 0
            $vmWriter writePop pointer 0
        }

        my compileStatements
        my eatSymbol "}"
    }

    method compileParameterList {} {
        if {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ")"} {
            return
        }

        while {1} {
            set type [my parseType]
            set name [my eatIdentifier]
            $symbolTable define $name $type arg

            if {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ","} {
                $tokenizer advance
            } else {
                break
            }
        }
    }

    method compileVarDec {} {
        my eatKeyword VAR
        set type [my parseType]

        set name [my eatIdentifier]
        $symbolTable define $name $type var

        while {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ","} {
            $tokenizer advance
            set name [my eatIdentifier]
            $symbolTable define $name $type var
        }

        my eatSymbol ";"
    }

    method compileStatements {} {
        while {[$tokenizer tokenType] eq "KEYWORD"} {
            switch -exact -- [$tokenizer keyword] {
                LET { my compileLet }
                IF { my compileIf }
                WHILE { my compileWhile }
                DO { my compileDo }
                RETURN { my compileReturn }
                default { break }
            }
        }
    }

    method compileDo {} {
        my eatKeyword DO
        my compileSubroutineCall
        my eatSymbol ";"
        $vmWriter writePop temp 0
    }

    method compileLet {} {
        my eatKeyword LET
        set varName [my eatIdentifier]

        set isArray 0
        if {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq "\["} {
            set isArray 1
            $tokenizer advance
            my compileExpression
            my eatSymbol "\]"
            my pushVariable $varName
            $vmWriter writeArithmetic add
        }

        my eatSymbol "="
        my compileExpression
        my eatSymbol ";"

        if {$isArray} {
            $vmWriter writePop temp 0
            $vmWriter writePop pointer 1
            $vmWriter writePush temp 0
            $vmWriter writePop that 0
        } else {
            my popVariable $varName
        }
    }

    method compileWhile {} {
        set lblExp [my newLabel WHILE_EXP]
        set lblEnd [my newLabel WHILE_END]

        $vmWriter writeLabel $lblExp

        my eatKeyword WHILE
        my eatSymbol "("
        my compileExpression
        my eatSymbol ")"

        $vmWriter writeArithmetic not
        $vmWriter writeIf $lblEnd

        my eatSymbol "{"
        my compileStatements
        my eatSymbol "}"

        $vmWriter writeGoto $lblExp
        $vmWriter writeLabel $lblEnd
    }

    method compileReturn {} {
        my eatKeyword RETURN

        if {!([$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ";")} {
            my compileExpression
        } else {
            $vmWriter writePush constant 0
        }

        my eatSymbol ";"
        $vmWriter writeReturn
    }

    method compileIf {} {
        set lblTrue [my newLabel IF_TRUE]
        set lblFalse [my newLabel IF_FALSE]
        set lblEnd [my newLabel IF_END]

        my eatKeyword IF
        my eatSymbol "("
        my compileExpression
        my eatSymbol ")"

        $vmWriter writeIf $lblTrue
        $vmWriter writeGoto $lblFalse
        $vmWriter writeLabel $lblTrue

        my eatSymbol "{"
        my compileStatements
        my eatSymbol "}"

        if {[$tokenizer tokenType] eq "KEYWORD" && [$tokenizer keyword] eq "ELSE"} {
            $vmWriter writeGoto $lblEnd
            $vmWriter writeLabel $lblFalse

            $tokenizer advance
            my eatSymbol "{"
            my compileStatements
            my eatSymbol "}"

            $vmWriter writeLabel $lblEnd
        } else {
            $vmWriter writeLabel $lblFalse
        }
    }

    method compileExpression {} {
        my compileTerm

        while {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] in {+ - * / & | < > =}} {
            set op [$tokenizer symbol]
            $tokenizer advance
            my compileTerm

            switch -exact -- $op {
                + { $vmWriter writeArithmetic add }
                - { $vmWriter writeArithmetic sub }
                * { $vmWriter writeCall Math.multiply 2 }
                / { $vmWriter writeCall Math.divide 2 }
                & { $vmWriter writeArithmetic and }
                | { $vmWriter writeArithmetic or }
                < { $vmWriter writeArithmetic lt }
                > { $vmWriter writeArithmetic gt }
                = { $vmWriter writeArithmetic eq }
            }
        }
    }

    method compileTerm {} {
        set tt [$tokenizer tokenType]

        if {$tt eq "INT_CONST"} {
            $vmWriter writePush constant [$tokenizer intVal]
            $tokenizer advance
            return
        }

        if {$tt eq "STRING_CONST"} {
            set str [$tokenizer stringVal]
            set len [string length $str]
            $vmWriter writePush constant $len
            $vmWriter writeCall String.new 1

            for {set i 0} {$i < $len} {incr i} {
                scan [string index $str $i] %c ascii
                $vmWriter writePush constant $ascii
                $vmWriter writeCall String.appendChar 2
            }

            $tokenizer advance
            return
        }

        if {$tt eq "KEYWORD"} {
            set kw [$tokenizer keyword]
            switch -exact -- $kw {
                TRUE {
                    $vmWriter writePush constant 0
                    $vmWriter writeArithmetic not
                }
                FALSE -
                NULL {
                    $vmWriter writePush constant 0
                }
                THIS {
                    $vmWriter writePush pointer 0
                }
                default {
                    my errorHere "Unexpected keyword constant '$kw'"
                }
            }
            $tokenizer advance
            return
        }

        if {$tt eq "IDENTIFIER"} {
            set name [$tokenizer identifier]
            $tokenizer advance

            if {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq "\["} {
                $tokenizer advance
                my compileExpression
                my eatSymbol "\]"

                my pushVariable $name
                $vmWriter writeArithmetic add
                $vmWriter writePop pointer 1
                $vmWriter writePush that 0
                return
            }

            if {[$tokenizer tokenType] eq "SYMBOL" && ([$tokenizer symbol] eq "(" || [$tokenizer symbol] eq ".")} {
                my compileSubroutineCallRest $name
                return
            }

            my pushVariable $name
            return
        }

        if {$tt eq "SYMBOL" && [$tokenizer symbol] eq "("} {
            $tokenizer advance
            my compileExpression
            my eatSymbol ")"
            return
        }

        if {$tt eq "SYMBOL" && ([$tokenizer symbol] eq "-" || [$tokenizer symbol] eq "~")} {
            set unaryOp [$tokenizer symbol]
            $tokenizer advance
            my compileTerm

            if {$unaryOp eq "-"} {
                $vmWriter writeArithmetic neg
            } else {
                $vmWriter writeArithmetic not
            }
            return
        }

        my errorHere "Unexpected term"
    }

    method compileSubroutineCall {} {
        set name [my eatIdentifier]
        my compileSubroutineCallRest $name
    }

    method compileSubroutineCallRest {name} {
        set callName ""
        set nArgs 0

        if {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq "."} {
            $tokenizer advance
            set subName [my eatIdentifier]

            set kind [$symbolTable kindOf $name]
            if {$kind ne "NONE"} {
                set segment [my getSegment $kind]
                set index [$symbolTable indexOf $name]
                $vmWriter writePush $segment $index
                incr nArgs

                set typeName [$symbolTable typeOf $name]
                set callName "$typeName.$subName"
            } else {
                set callName "$name.$subName"
            }

            my eatSymbol "("
        } else {
            $vmWriter writePush pointer 0
            incr nArgs
            set callName "$className.$name"
            my eatSymbol "("
        }

        set nArgs [expr {$nArgs + [my compileExpressionList]}]
        my eatSymbol ")"

        $vmWriter writeCall $callName $nArgs
    }

    method compileExpressionList {} {
        set nArgs 0

        if {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ")"} {
            return $nArgs
        }

        my compileExpression
        incr nArgs

        while {[$tokenizer tokenType] eq "SYMBOL" && [$tokenizer symbol] eq ","} {
            $tokenizer advance
            my compileExpression
            incr nArgs
        }

        return $nArgs
    }

    method close {} {
        $vmWriter close
        catch {$symbolTable destroy}
    }
}
