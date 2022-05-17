#include "Json.au3"
$sText = FileRead("theme.json")
$oData = Json_Decode($sText)

$oModels =$oData.Item("model")
For $sModel In $oModels
   c( "Model:" & $sModel )
   $oModel = $oModels.Item( $sModel )
   c( "type:" & VarGetType($oModel) )
   c( "Name:" & $oModel.Item( "kind" ) )
Next


Func e( $err, $str)
   c("whatever"&$str&@CRLF)
   Return SetError($err)
EndFunc

Func c($str)
   ConsoleWrite($str&@crlf)
EndFunc
