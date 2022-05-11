#include <File.au3>
#include <Array.au3>

$sPath = "C:\Program Files (x86)\Steam\steamapps\workshop\content\1968650"

$aFolders = _FileListToArray( $sPath, "*", $FLTA_FOLDERS )
If @error Then
   c("a error:" & @error)
   Exit
EndIf

Global $aDances[0]

For $i = 1 To UBound($aFolders)-1
   $sSubPath = $sPath & "\" & $aFolders[$i]
   ; c( "sub path:" & $sSubPath)
   $aFiles = _FileListToArray($sSubPath, "*.vmd", $FLTA_FILES )
   If @error=4 Then ContinueLoop	; File not found.
   If @error=1 Then
	  c("error in getting folder")
	  ExitLoop
   EndIf
   ; One or more files found
   $iCount = UBound( $aDances )
   ReDim $aDances[ $iCount+$aFiles[0] ]
   For $j=1 to $aFiles[0]
	  $aDances[$iCount+$j-1]=$aFiles[$j]
   Next

Next

_ArrayDisplay($aDances)

Func c($str)
   ConsoleWrite($str&@CRLF)
EndFunc
