package provide CompilationEngine 1.0

oo::class create CompilationEngine {
    variable tokenizer
    variable vmWriter
    variable symbolTable
    variable className
    variable labelCounter

    constructor {jackTokenizer outFilename} {
        set tokenizer 
        set vmWriter [VMWriter new ]
        set symbolTable [SymbolTable new]
        set labelCounter 0
    }

    method getSegment {kind} {
        switch -exact --  {
            "field" {return "this"}
            "var"   {return "local"}
            "arg"   {return "argument"}
            "static" {return "static"}
            default {return ""}
        }
    }

    method compileClass {} {
         advance
        set className [ identifier]
         advance
         advance

        while {[ tokenType] eq "KEYWORD" && ([ keyword] eq "STATIC" || [ keyword] eq "FIELD")} {
            my compileClassVarDec
        }

        while {[ tokenType] eq "KEYWORD" && ([ keyword] eq "CONSTRUCTOR" || [ keyword] eq "FUNCTION" || [ keyword] eq "METHOD")} {
            my compileSubroutine
        }
         advance
    }

    method compileClassVarDec {} {
        set kind [ keyword]
         advance
        
        if {[ tokenType] eq "KEYWORD"} {
            set type [ keyword]
        } else {
            set type [ identifier]
        }
         advance
        
        set name [ identifier]
         define   
         advance
        
        while {[ tokenType] eq "SYMBOL" && [ symbol] eq ","} {
             advance
            set name [ identifier]
             define   
             advance
        }
         advance
    }

    method compileSubroutine {} {
         startSubroutine
        set subroutineType [ keyword]
         advance
        
        if {[ tokenType] eq "KEYWORD"} {
            set returnType [ keyword]
        } else {
            set returnType [ identifier]
        }
         advance
        
        set subroutineName [ identifier]
         advance
        
        if { eq "METHOD"} {
             define "this"  "arg"
        }
        
         advance
        my compileParameterList
         advance
        
         advance
        
        while {[ tokenType] eq "KEYWORD" && [ keyword] eq "VAR"} {
            my compileVarDec
        }
        
        set nLocals [ varCount "var"]
         writeFunction "." 
        
        if { eq "CONSTRUCTOR"} {
            set nFields [ varCount "field"]
             writePush "constant" 
             writeCall "Memory.alloc" 1
             writePop "pointer" 0
        } elseif { eq "METHOD"} {
             writePush "argument" 0
             writePop "pointer" 0
        }
        
        my compileStatements
         advance
    }

    method compileParameterList {} {
        if {[ tokenType] ne "SYMBOL" || [ symbol] ne ")"} {
            if {[ tokenType] eq "KEYWORD"} {
                set type [ keyword]
            } else {
                set type [ identifier]
            }
             advance
            
            set name [ identifier]
             define   "arg"
             advance
            
            while {[ tokenType] eq "SYMBOL" && [ symbol] eq ","} {
                 advance
                if {[ tokenType] eq "KEYWORD"} {
                    set type [ keyword]
                } else {
                    set type [ identifier]
                }
                 advance
                
                set name [ identifier]
                 define   "arg"
                 advance
            }
        }
    }

    method compileVarDec {} {
        set kind "var"
         advance
        
        if {[ tokenType] eq "KEYWORD"} {
            set type [ keyword]
        } else {
            set type [ identifier]
        }
         advance
        
        set name [ identifier]
         define   
         advance
        
        while {[ tokenType] eq "SYMBOL" && [ symbol] eq ","} {
             advance
            set name [ identifier]
             define   
             advance
        }
         advance
    }

    method compileStatements {} {
        while {[ tokenType] eq "KEYWORD"} {
            set kw [ keyword]
            switch -exact --  {
                "LET" { my compileLet }
                "IF" { my compileIf }
                "WHILE" { my compileWhile }
                "DO" { my compileDo }
                "RETURN" { my compileReturn }
                default { break }
            }
        }
    }

    method compileDo {} {
         advance
        set name [ identifier]
         advance
        
        set nArgs 0
        set callName ""
        
        if {[ tokenType] eq "SYMBOL" && [ symbol] eq "."} {
             advance
            set subName [ identifier]
             advance
            
            set kind [ kindOf ]
            set type [ typeOf ]
            
            if { ne "NONE"} {
                 writePush [my getSegment ] [ indexOf ]
                set callName "."
                set nArgs 1
            } else {
                set callName "."
            }
        } else {
             writePush "pointer" 0
            set callName "."
            set nArgs 1
        }
        
         advance
        set nArgs [expr { + [my compileExpressionList]}]
         advance
         advance
        
         writeCall  
         writePop "temp" 0
    }

    method compileLet {} {
         advance
        set varName [ identifier]
         advance
        
        set isArray 0
        if {[ tokenType] eq "SYMBOL" && [ symbol] eq "\["} {
            set isArray 1
             advance
            my compileExpression
             advance
            
            set kind [ kindOf ]
            set index [ indexOf ]
             writePush [my getSegment ] 
             writeArithmetic "add"
        }
        
         advance
        my compileExpression
         advance
        
        if {} {
             writePop "temp" 0
             writePop "pointer" 1
             writePush "temp" 0
             writePop "that" 0
        } else {
            set kind [ kindOf ]
            set index [ indexOf ]
             writePop [my getSegment ] 
        }
    }

    method compileWhile {} {
        set labelNum 
        incr labelCounter
        set lblExp "WHILE_EXP"
        set lblEnd "WHILE_END"
        
         writeLabel 
         advance
         advance
        my compileExpression
         advance
        
         writeArithmetic "not"
         writeIf 
        
         advance
        my compileStatements
         advance
        
         writeGoto 
         writeLabel 
    }

    method compileReturn {} {
         advance
        if {[ tokenType] ne "SYMBOL" || [ symbol] ne ";"} {
            my compileExpression
        } else {
             writePush "constant" 0
        }
         advance
         writeReturn
    }

    method compileIf {} {
        set labelNum 
        incr labelCounter
        set lblTrue "IF_TRUE"
        set lblFalse "IF_FALSE"
        set lblEnd "IF_END"
        
         advance
         advance
        my compileExpression
         advance
        
         writeIf 
         writeGoto 
         writeLabel 
        
         advance
        my compileStatements
         advance
        
        if {[ tokenType] eq "KEYWORD" && [ keyword] eq "ELSE"} {
             writeGoto 
             writeLabel 
             advance
             advance
            my compileStatements
             advance
             writeLabel 
        } else {
             writeLabel 
        }
    }

    method compileExpression {} {
        my compileTerm
        
        while {[ tokenType] eq "SYMBOL" && [ symbol] in {"+" "-" "*" "/" "&" "|" "<" ">" "="}} {
            set op [ symbol]
             advance
            my compileTerm
            
            switch -exact --  {
                "+" {  writeArithmetic "add" }
                "-" {  writeArithmetic "sub" }
                "*" {  writeCall "Math.multiply" 2 }
                "/" {  writeCall "Math.divide" 2 }
                "&" {  writeArithmetic "and" }
                "|" {  writeArithmetic "or" }
                "<" {  writeArithmetic "lt" }
                ">" {  writeArithmetic "gt" }
                "=" {  writeArithmetic "eq" }
            }
        }
    }

    method compileTerm {} {
        set type [ tokenType]
        
        if { eq "INT_CONST"} {
             writePush "constant" [ intVal]
             advance
        } elseif { eq "STRING_CONST"} {
            set str [ stringVal]
            set len [string length ]
             writePush "constant" 
             writeCall "String.new" 1
            for {set i 0} { < } {incr i} {
                scan [string index  ] %c charCode
                 writePush "constant" 
                 writeCall "String.appendChar" 2
            }
             advance
        } elseif { eq "KEYWORD"} {
            set kw [ keyword]
            if { eq "TRUE"} {
                 writePush "constant" 0
                 writeArithmetic "not"
            } elseif { eq "FALSE" ||  eq "NULL"} {
                 writePush "constant" 0
            } elseif { eq "THIS"} {
                 writePush "pointer" 0
            }
             advance
        } elseif { eq "IDENTIFIER"} {
            set name [ identifier]
             advance
            
            if {[ tokenType] eq "SYMBOL" && [ symbol] eq "\["} {
                 advance
                my compileExpression
                 advance
                
                set kind [ kindOf ]
                set index [ indexOf ]
                 writePush [my getSegment ] 
                 writeArithmetic "add"
                 writePop "pointer" 1
                 writePush "that" 0
            } elseif {[ tokenType] eq "SYMBOL" && ([ symbol] eq "(" || [ symbol] eq ".")} {
                set callName ""
                set nArgs 0
                
                if {[ symbol] eq "."} {
                     advance
                    set subName [ identifier]
                     advance
                    
                    set kind [ kindOf ]
                    set typeName [ typeOf ]
                    
                    if { ne "NONE"} {
                         writePush [my getSegment ] [ indexOf ]
                        set callName "."
                        set nArgs 1
                    } else {
                        set callName "."
                    }
                } else {
                     writePush "pointer" 0
                    set callName "."
                    set nArgs 1
                }
                
                 advance
                set nArgs [expr { + [my compileExpressionList]}]
                 advance
                
                 writeCall  
            } else {
                set kind [ kindOf ]
                set index [ indexOf ]
                 writePush [my getSegment ] 
            }
        } elseif { eq "SYMBOL" && [ symbol] eq "("} {
             advance
            my compileExpression
             advance
        } elseif { eq "SYMBOL" && ([ symbol] eq "-" || [ symbol] eq "~")} {
            set op [ symbol]
             advance
            my compileTerm
            if { eq "-"} {
                 writeArithmetic "neg"
            } else {
                 writeArithmetic "not"
            }
        }
    }

    method compileExpressionList {} {
        set nArgs 0
        if {[ tokenType] ne "SYMBOL" || [ symbol] ne ")"} {
            my compileExpression
            incr nArgs
            while {[ tokenType] eq "SYMBOL" && [ symbol] eq ","} {
                 advance
                my compileExpression
                incr nArgs
            }
        }
        return 
    }

    method close {} {
         close
    }
}
