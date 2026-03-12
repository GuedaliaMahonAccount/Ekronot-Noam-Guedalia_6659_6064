# ID1: 337966659
# Name1: גדליה סבע
# ID2: 322766064
# Name2: נועם חדד


# ==========================================
# פונקציות עזר - פקודות אריתמטיות
# ==========================================
proc handleAdd {outFile} {
    puts $outFile "command: add"
}

proc handleSub {outFile} {
    puts $outFile "command: sub"
}

proc handleNeg {outFile} {
    puts $outFile "command: neg"
}

# ==========================================
# פונקציות עזר - פקודות לוגיות
# ==========================================
proc handleEq {outFile counterVarName} {
    upvar 1 $counterVarName count
    incr count
    puts $outFile "command: eq"
    puts $outFile "counter: $count"
}

proc handleGt {outFile counterVarName} {
    upvar 1 $counterVarName count
    incr count
    puts $outFile "command: gt"
    puts $outFile "counter: $count"
}

proc handleLt {outFile counterVarName} {
    upvar 1 $counterVarName count
    incr count
    puts $outFile "command: lt"
    puts $outFile "counter: $count"
}

# ==========================================
# פונקציות עזר - פקודות גישה לזיכרון
# ==========================================
proc handlePush {outFile segment index} {
    puts $outFile "command: push segment $segment index $index"
}

proc handlePop {outFile segment index} {
    puts $outFile "command: pop segment $segment index $index"
}

# ==========================================
# התוכנית הראשית
# ==========================================

# 1. קבלת קלט מהמשתמש
puts -nonewline "Please enter the directory path: "
flush stdout
gets stdin dir_path

# Clean up path to avoid trailing slashes issues
set clean_dir_path [string trimright $dir_path "/\\"]

# המרת הנתיב לפורמט סטנדרטי (פותר בעיות של לוכסנים הפוכים בווינדוס)
set dirPath [file normalize $dirPath]

# 2. חילוץ שם התיקייה ויצירת קובץ הפלט
set dirName [file tail $dirPath]
set asmFileName "${dirName}.asm"
set outFilePath [file join $dirPath $asmFileName]

# פתיחת קובץ הפלט לכתיבה
set outFile [open $outFilePath w]

# הגדרת משתנה גלובאלי לשמירת שם הקובץ הנוכחי (ללא סיומת)
global currentFileName

# 3. מעבר על כל קבצי ה-VM בתיקייה
set vmFiles [glob -nocomplain -directory $dirPath *.vm]

foreach vmFile $vmFiles {
    # איפוס מונה לוגי עבור הקובץ הנוכחי
    set logicalCounter 0
    
    # שמירת שם הקובץ ללא הסיומת במשתנה הגלובאלי
    set currentFileName [file rootname [file tail $vmFile]]
    
    # פתיחת קובץ הקלט לקריאה
    set inFile [open $vmFile r]
    
    # קריאת הקובץ שורה אחר שורה
    while {[gets $inFile line] >= 0} {
        # ניקוי רווחים מיותרים והתעלמות משורות ריקות
        set line [string trim $line]
        if {$line eq ""} continue
        
        # פירוק השורה למילים
        set words [regexp -all -inline {\S+} $line]
        set command [lindex $words 0]
        
        # ניתוב לפונקציית העזר המתאימה
        switch -exact -- $command {
            "add"  { handleAdd $outFile }
            "sub"  { handleSub $outFile }
            "neg"  { handleNeg $outFile }
            "eq"   { handleEq $outFile logicalCounter }
            "gt"   { handleGt $outFile logicalCounter }
            "lt"   { handleLt $outFile logicalCounter }
            "push" { handlePush $outFile [lindex $words 1] [lindex $words 2] }
            "pop"  { handlePop $outFile [lindex $words 1] [lindex $words 2] }
            default {
                # ניתן להוסיף טיפול בפקודות אחרות במידה ויהיו בהמשך
            }
        }
    }
    
    # סגירת קובץ הקלט והדפסת הודעה מתאימה
    close $inFile
    puts "End of input file:  [file tail $vmFile]"
}

# 4. סיום התוכנית - סגירת קובץ הפלט והדפסת הודעת סיום
close $outFile
puts "Output file is ready: $asmFileName"