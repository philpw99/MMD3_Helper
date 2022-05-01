$h = WinGetHandle("[REGEXPTITLE:DMMDCore$]","")
c("H:" &$h)

Func c($str)
   ConsoleWrite($str&@CRLF)
EndFunc
