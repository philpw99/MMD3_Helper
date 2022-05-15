; ConsoleWrite("out:" & FileExists("C:\Program Files (x86)\Steam\steamapps\workshop\content\1968650\2808241801") & @CRLF)

$sPath = RegRead("HKEY_CURRENT_USER\Software\Valve\Steam","SteamPath")
$sPath = StringReplace( $sPath, "/", "\" ) & "\steamapps\workshop\content\1968650\2808241801"
c("Path:"& $sPath)

Func c($str)
   ConsoleWrite($str&@crlf)
EndFunc
