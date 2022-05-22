	Global Const $HTTP_STATUS_OK = 200

	;;Instantiate a WinHttpRequest object
	Local $WinHttpReq = ObjCreate("winhttp.winhttprequest.5.1")
	Local $id = Random( 0, 309, 1)
	Local $url = "https://jokeapi-v2.p.rapidapi.com/joke/Any?format=json&idRange=" & $id & "-" & String($id+10) & "&blacklistFlags=racist"
	$WinHttpReq.Open("GET", $url, false)
	  if @error Then
	   Exit
	   ; Return SetError( e(1, @ScriptLineNumber) )
	EndIf
	$WinHttpReq.SetRequestHeader( "Content-Type", "application/json")
	$WinHttpReq.SetRequestHeader( "X-Rapidapi-Host", "jokeapi-v2.p.rapidapi.com" )
	$WinHttpReq.SetRequestHeader( "X-RapidAPI-Key", "2f3b011dc6msh8f16a2e0b3970a8p15ab50jsna154630ffcba")

   ;;Initialize an HTTP request.
   $WinHttpReq.send()
   if @error Then
	   c("problem sending request")
	   Exit
   EndIf
   ;;Get all response headers
   If $WinHttpReq.Status <> $HTTP_STATUS_OK Then
	  c( "Error with http status:" & $WinHttpReq.Status)
	  Exit
   EndIf


MsgBox( 0, "response", $WinHttpReq.ResponseText)

Func c($str)
   ConsoleWrite($str&@crlf)
EndFunc