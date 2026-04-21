# Main Analyzer script for Jack Compiler (Part 1 - Syntax Analysis)
# Usage: tclsh JackAnalyzer.tcl <file.jack|directory>

namespace eval JackTokenizer {
    variable keywords {
        "class" "constructor" "function" "method" "field" "static" 
        "var" "int" "char" "boolean" "void" "true" "false" 
        "null" "this" "let" "do" "if" "else" "while" "return"
    }
    variable tokens {}

    proc tokenize {content} {
        variable keywords
        variable tokens
        set tokens {}

        # Remove block comments /* ... */ and /** ... */
        regsub -all {(?s)/\*.*?\*/} $content "" content
        
        # Remove single line comments // ...
        regsub -all {//[^\n]*} $content "" content

        # Regex pattern for tokens
        # Group 1: String Constant
        # Group 2: Symbol
        # Group 3: Integer Constant
        # Group 4: Identifier or Keyword
        set pattern {("[^"\n]*")|([\{\}\(\)\[\]\.\,\;\+\-\*\/\&\|\<\>\=\~])|(\d+)|([a-zA-Z_]\w*)}
        
        set matches [regexp -all -inline $pattern $content]
        
        foreach {full str sym int id} $matches {
            if {$str ne ""} {
                set val [string range $str 1 end-1]
                lappend tokens [list "stringConstant" $val]
            } elseif {$sym ne ""} {
                set val $sym
                # Handle XML special characters
                if {$val eq "<"} { set val "&lt;" }
                if {$val eq ">"} { set val "&gt;" }
                if {$val eq "\""} { set val "&quot;" }
                if {$val eq "&"} { set val "&amp;" }
                lappend tokens [list "symbol" $val]
            } elseif {$int ne ""} {
                lappend tokens [list "integerConstant" $int]
            } elseif {$id ne ""} {
                if {$id in $keywords} {
                    lappend tokens [list "keyword" $id]
                } else {
                    lappend tokens [list "identifier" $id]
                }
            }
        }
        return $tokens
    }

    proc writeTokensXML {outFile tokensList} {
        set fp [open $outFile w]
        puts $fp "<tokens>"
        foreach token $tokensList {
            lassign $token type value
            puts $fp "<$type> $value </$type>"
        }
        puts $fp "</tokens>"
        close $fp
    }
}

namespace eval CompilationEngine {
    variable tokens {}
    variable currentTokenIndex 0
    variable outFilePointer ""
    variable indentLevel 0

    proc init {tokensList outputFile} {
        variable tokens
        variable currentTokenIndex
        variable outFilePointer
        variable indentLevel
        
        set tokens $tokensList
        set currentTokenIndex 0
        set indentLevel 0
        set outFilePointer [open $outputFile w]
        
        compileClass
        close $outFilePointer
    }

    proc writeLine {line} {
        variable outFilePointer
        variable indentLevel
        set indent [string repeat "  " $indentLevel]
        puts $outFilePointer "${indent}${line}"
    }

    proc writeTag {tag value} {
        writeLine "<$tag> $value </$tag>"
    }

    proc peek {} {
        variable tokens
        variable currentTokenIndex
        if {$currentTokenIndex >= [llength $tokens]} {
            return ""
        }
        return [lindex $tokens $currentTokenIndex]
    }

    proc advance {} {
        variable tokens
        variable currentTokenIndex
        set token [peek]
        if {$token ne ""} {
            lassign $token type value
            writeTag $type $value
            incr currentTokenIndex
        }
        return $token
    }

    proc compileClass {} {
        variable indentLevel
        writeLine "<class>"
        incr indentLevel

        advance ;# 'class'
        advance ;# className
        advance ;# '{'

        # Class variable declarations
        while {1} {
            set token [peek]
            if {$token eq ""} break
            lassign $token type value
            if {$value in {"static" "field"}} {
                compileClassVarDec
            } else {
                break
            }
        }

        # Subroutine declarations
        while {1} {
            set token [peek]
            if {$token eq ""} break
            lassign $token type value
            if {$value in {"constructor" "function" "method"}} {
                compileSubroutine
            } else {
                break
            }
        }

        advance ;# '}'
        
        incr indentLevel -1
        writeLine "</class>"
    }

    proc compileClassVarDec {} {
        variable indentLevel
        writeLine "<classVarDec>"
        incr indentLevel

        advance ;# 'static' or 'field'
        advance ;# type
        advance ;# varName

        while {1} {
            set token [peek]
            lassign $token type value
            if {$value eq ","} {
                advance ;# ','
                advance ;# varName
            } else {
                break
            }
        }
        advance ;# ';'

        incr indentLevel -1
        writeLine "</classVarDec>"
    }

    proc compileSubroutine {} {
        variable indentLevel
        writeLine "<subroutineDec>"
        incr indentLevel

        advance ;# 'constructor', 'function', or 'method'
        advance ;# 'void' or type
        advance ;# subroutineName
        advance ;# '('
        compileParameterList
        advance ;# ')'
        
        # subroutineBody
        writeLine "<subroutineBody>"
        incr indentLevel
        advance ;# '{'

        while {1} {
            set token [peek]
            lassign $token type value
            if {$value eq "var"} {
                compileVarDec
            } else {
                break
            }
        }

        compileStatements
        advance ;# '}'
        
        incr indentLevel -1
        writeLine "</subroutineBody>"

        incr indentLevel -1
        writeLine "</subroutineDec>"
    }

    proc compileParameterList {} {
        variable indentLevel
        writeLine "<parameterList>"
        incr indentLevel

        set token [peek]
        lassign $token type value
        if {$value ne ")"} {
            advance ;# type
            advance ;# varName
            while {1} {
                set nextToken [peek]
                lassign $nextToken nextType nextValue
                if {$nextValue eq ","} {
                    advance ;# ','
                    advance ;# type
                    advance ;# varName
                } else {
                    break
                }
            }
        }

        incr indentLevel -1
        writeLine "</parameterList>"
    }

    proc compileVarDec {} {
        variable indentLevel
        writeLine "<varDec>"
        incr indentLevel

        advance ;# 'var'
        advance ;# type
        advance ;# varName

        while {1} {
            set token [peek]
            lassign $token type value
            if {$value eq ","} {
                advance ;# ','
                advance ;# varName
            } else {
                break
            }
        }
        advance ;# ';'

        incr indentLevel -1
        writeLine "</varDec>"
    }

    proc compileStatements {} {
        variable indentLevel
        writeLine "<statements>"
        incr indentLevel

        while {1} {
            set token [peek]
            if {$token eq ""} break
            lassign $token type value
            
            if {$value eq "let"} { compileLet } \
            elseif {$value eq "if"} { compileIf } \
            elseif {$value eq "while"} { compileWhile } \
            elseif {$value eq "do"} { compileDo } \
            elseif {$value eq "return"} { compileReturn } \
            else { break }
        }

        incr indentLevel -1
        writeLine "</statements>"
    }

    proc compileLet {} {
        variable indentLevel
        writeLine "<letStatement>"
        incr indentLevel

        advance ;# 'let'
        advance ;# varName

        set token [peek]
        lassign $token type value
        if {$value eq "\["} {
            advance ;# '['
            compileExpression
            advance ;# ']'
        }

        advance ;# '='
        compileExpression
        advance ;# ';'

        incr indentLevel -1
        writeLine "</letStatement>"
    }

    proc compileIf {} {
        variable indentLevel
        writeLine "<ifStatement>"
        incr indentLevel

        advance ;# 'if'
        advance ;# '('
        compileExpression
        advance ;# ')'
        advance ;# '{'
        compileStatements
        advance ;# '}'

        set token [peek]
        if {$token ne ""} {
            lassign $token type value
            if {$value eq "else"} {
                advance ;# 'else'
                advance ;# '{'
                compileStatements
                advance ;# '}'
            }
        }

        incr indentLevel -1
        writeLine "</ifStatement>"
    }

    proc compileWhile {} {
        variable indentLevel
        writeLine "<whileStatement>"
        incr indentLevel

        advance ;# 'while'
        advance ;# '('
        compileExpression
        advance ;# ')'
        advance ;# '{'
        compileStatements
        advance ;# '}'

        incr indentLevel -1
        writeLine "</whileStatement>"
    }

    proc compileDo {} {
        variable indentLevel
        writeLine "<doStatement>"
        incr indentLevel

        advance ;# 'do'
        
        # Subroutine call (identifier, then possibly '.' then identifier)
        advance ;# identifier
        set token [peek]
        lassign $token type value
        if {$value eq "."} {
            advance ;# '.'
            advance ;# identifier
        }
        advance ;# '('
        compileExpressionList
        advance ;# ')'
        advance ;# ';'

        incr indentLevel -1
        writeLine "</doStatement>"
    }

    proc compileReturn {} {
        variable indentLevel
        writeLine "<returnStatement>"
        incr indentLevel

        advance ;# 'return'
        set token [peek]
        lassign $token type value
        if {$value ne ";"} {
            compileExpression
        }
        advance ;# ';'

        incr indentLevel -1
        writeLine "</returnStatement>"
    }

    proc compileExpression {} {
        variable indentLevel
        writeLine "<expression>"
        incr indentLevel

        compileTerm
        
        while {1} {
            set token [peek]
            lassign $token type value
            if {$value in {"+" "-" "*" "/" "&amp;" "|" "&lt;" "&gt;" "="}} {
                advance ;# op
                compileTerm
            } else {
                break
            }
        }

        incr indentLevel -1
        writeLine "</expression>"
    }

    proc compileTerm {} {
        variable indentLevel
        writeLine "<term>"
        incr indentLevel

        set token [peek]
        lassign $token type value

        if {$type eq "integerConstant" || $type eq "stringConstant" || $value in {"true" "false" "null" "this"}} {
            advance
        } elseif {$value in {"-" "~"}} {
            advance ;# unaryOp
            compileTerm
        } elseif {$value eq "("} {
            advance ;# '('
            compileExpression
            advance ;# ')'
        } elseif {$type eq "identifier"} {
            # Could be varName, varName[expression], subroutineName(..), or className.subroutineName(..)
            advance ;# identifier
            set nextToken [peek]
            lassign $nextToken nextType nextValue
            
            if {$nextValue eq "\["} {
                advance ;# '['
                compileExpression
                advance ;# ']'
            } elseif {$nextValue eq "("} {
                advance ;# '('
                compileExpressionList
                advance ;# ')'
            } elseif {$nextValue eq "."} {
                advance ;# '.'
                advance ;# subroutineName
                advance ;# '('
                compileExpressionList
                advance ;# ')'
            }
        }

        incr indentLevel -1
        writeLine "</term>"
    }

    proc compileExpressionList {} {
        variable indentLevel
        writeLine "<expressionList>"
        incr indentLevel

        set token [peek]
        lassign $token type value
        if {$value ne ")"} {
            compileExpression
            while {1} {
                set nextToken [peek]
                lassign $nextToken nextType nextValue
                if {$nextValue eq ","} {
                    advance ;# ','
                    compileExpression
                } else {
                    break
                }
            }
        }

        incr indentLevel -1
        writeLine "</expressionList>"
    }
}

# Main execution block
if {$argc == 0} {
    puts "Usage: tclsh JackAnalyzer.tcl <file_or_directory>"
    exit 1
}

set path [lindex $argv 0]
set files {}

if {[file isdirectory $path]} {
    set files [glob -nocomplain -directory $path *.jack]
} elseif {[file extension $path] eq ".jack"} {
    lappend files $path
} else {
    puts "Error: Invalid path or file type."
    exit 1
}

foreach file $files {
    puts "Analyzing $file..."
    set fp [open $file r]
    set content [read $fp]
    close $fp

    # 1. Tokenizing
    set tokens [JackTokenizer::tokenize $content]
    
    set basePath [file rootname $file]
    set tokenXmlFile "${basePath}T.xml"
    JackTokenizer::writeTokensXML $tokenXmlFile $tokens
    puts "  -> Generated $tokenXmlFile"

    # 2. Parsing
    set treeXmlFile "${basePath}.xml"
    CompilationEngine::init $tokens $treeXmlFile
    puts "  -> Generated $treeXmlFile"
}