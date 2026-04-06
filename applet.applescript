on open location theURL
	set bundlePath to POSIX path of (path to me)
	set scriptPath to bundlePath & "Contents/Resources/Scripts/meet-chooser.sh"
	do shell script "bash " & quoted form of scriptPath & " " & quoted form of theURL
end open location
